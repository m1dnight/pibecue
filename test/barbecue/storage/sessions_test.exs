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
end
