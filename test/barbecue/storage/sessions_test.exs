defmodule Barbecue.Storage.SessionsTest do
  # async: false because these tests touch the shared application DB and
  # need to coordinate with the singleton Monitor process.
  use ExUnit.Case, async: false

  alias Barbecue.{Monitor, Repo}
  alias Barbecue.Storage.{Session, Sessions, State}

  import Ecto.Query

  setup do
    # Stop the periodic monitor so it doesn't insert measurements that would
    # tangle with our session-id assertions or break the cleanup below.
    Monitor.stop()
    # Per AGENTS.md: drain any in-flight :measure message before continuing.
    _ = :sys.get_state(Monitor)

    # Snapshot what's already in the DB so on_exit can scope cleanup to just
    # the rows this test creates.
    existing_session_ids = Repo.all(from(s in Session, select: s.id))

    on_exit(fn ->
      Repo.delete_all(from(st in State, where: st.session_id not in ^existing_session_ids))
      Repo.delete_all(from(s in Session, where: s.id not in ^existing_session_ids))
      Monitor.start()
    end)

    %{existing_session_ids: existing_session_ids}
  end

  describe "current/0" do
    # The current session is the most recently inserted one (highest id),
    # so the UI and create_state always attach to the active session.
    test "returns the session with the highest id" do
      {:ok, _s1} = Sessions.start_new()
      {:ok, s2} = Sessions.start_new()

      assert Sessions.current().id == s2.id
    end
  end

  describe "start_new/0" do
    # A new session must always get a strictly larger id than any existing
    # one so the "highest id = current" rule keeps holding.
    test "creates a session with a higher id than the previous current" do
      before = Sessions.current()
      {:ok, new} = Sessions.start_new()

      assert new.id > before.id
    end

    # start_new persists the row, so after calling it the count of sessions
    # in the DB should grow by exactly one.
    test "persists the new session" do
      count_before = Repo.aggregate(Session, :count, :id)
      {:ok, _} = Sessions.start_new()
      count_after = Repo.aggregate(Session, :count, :id)

      assert count_after == count_before + 1
    end
  end

  describe "ensure_current/0" do
    # When a session already exists, ensure_current returns it unchanged
    # — no new row is inserted.
    test "returns the existing session without creating a new one" do
      count_before = Repo.aggregate(Session, :count, :id)
      result = Sessions.ensure_current()
      count_after = Repo.aggregate(Session, :count, :id)

      assert result.id == Sessions.current().id
      assert count_after == count_before
    end
  end

  describe "list/0" do
    # Listing should return sessions in newest-first order so the UI can
    # display recent runs at the top.
    test "returns all sessions sorted newest first" do
      {:ok, s1} = Sessions.start_new()
      {:ok, s2} = Sessions.start_new()

      ids = Sessions.list() |> Enum.map(& &1.id)
      assert s2.id in ids
      assert s1.id in ids

      # Confirm s2 comes before s1 in the list (s2 is newer).
      assert Enum.find_index(ids, &(&1 == s2.id)) <
               Enum.find_index(ids, &(&1 == s1.id))
    end
  end

  describe "current_started_at/0" do
    # No measurements means there's no defined start time yet — used by the
    # home page to fall back to "now".
    test "returns nil when the current session has no measurements" do
      {:ok, _session} = Sessions.start_new()
      assert Sessions.current_started_at() == nil
    end

    # Once measurements are linked to the current session, the result must
    # be the earliest one's inserted_at — independent of any time window
    # the chart happens to be showing.
    test "returns the earliest measurement's inserted_at for the current session" do
      {:ok, session} = Sessions.start_new()
      earliest = ~U[2026-04-30 09:09:00Z]
      latest = DateTime.add(earliest, 3600, :second)

      insert_state!(session.id, latest)
      insert_state!(session.id, earliest)

      assert DateTime.compare(Sessions.current_started_at(), earliest) == :eq
    end
  end

  describe "list_with_stats/0" do
    # Sessions without measurements should appear with nil time fields and
    # zero count, so the UI can render an "empty" state for them.
    test "returns nil times and zero count for an empty session" do
      {:ok, session} = Sessions.start_new()

      row = Sessions.list_with_stats() |> Enum.find(&(&1.id == session.id))

      assert row.started_at == nil
      assert row.ended_at == nil
      assert row.duration_seconds == nil
      assert row.measurement_count == 0
    end

    # When a session has measurements, started_at/ended_at must reflect the
    # min/max of the measurements' inserted_at, and duration must be the gap
    # between them.
    test "computes started_at, ended_at, and duration from measurements" do
      {:ok, session} = Sessions.start_new()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      later = DateTime.add(now, 5, :second)

      insert_state!(session.id, now)
      insert_state!(session.id, later)

      row = Sessions.list_with_stats() |> Enum.find(&(&1.id == session.id))

      assert row.measurement_count == 2
      assert DateTime.compare(row.started_at, now) == :eq
      assert DateTime.compare(row.ended_at, later) == :eq
      assert row.duration_seconds == 5
    end
  end

  defp insert_state!(session_id, inserted_at) do
    Repo.insert!(%State{
      temperature: 100.0,
      fan_speed: 0.5,
      target_temperature: 110.0,
      session_id: session_id,
      inserted_at: inserted_at,
      updated_at: inserted_at
    })
  end
end
