defmodule Barbecue.Storage.StatesDbTest do
  # async: false because these tests touch the shared application DB and
  # need to coordinate with the singleton Monitor process.
  use ExUnit.Case, async: false

  alias Barbecue.{Monitor, Repo}
  alias Barbecue.Storage.{Session, Sessions, State, States}

  import Ecto.Query

  setup do
    Monitor.stop()
    _ = :sys.get_state(Monitor)

    existing_session_ids = Repo.all(from(s in Session, select: s.id))

    on_exit(fn ->
      Repo.delete_all(from(st in State, where: st.session_id not in ^existing_session_ids))
      Repo.delete_all(from(s in Session, where: s.id not in ^existing_session_ids))
      Monitor.start()
    end)

    :ok
  end

  describe "create_state/1" do
    # When the caller doesn't pass a session_id, the new measurement must
    # be attached to the current (most-recent) session automatically.
    test "auto-fills session_id with the current session" do
      {:ok, session} = Sessions.start_new()

      attrs = %{temperature: 100.0, fan_speed: 0.5, target_temperature: 110.0}
      {:ok, state} = States.create_state(attrs)

      assert state.session_id == session.id
    end

    # Passing an explicit session_id must take precedence over the auto-fill,
    # so callers can attach a measurement to an arbitrary session if needed.
    test "uses the provided session_id when given" do
      {:ok, older} = Sessions.start_new()
      {:ok, _newer} = Sessions.start_new()

      attrs = %{
        temperature: 100.0,
        fan_speed: 0.5,
        target_temperature: 110.0,
        session_id: older.id
      }

      {:ok, state} = States.create_state(attrs)

      assert state.session_id == older.id
    end

    # After start_new the next auto-filled measurement must use the new
    # session — this is what makes the "click new session" UX work.
    test "subsequent measurements after start_new attach to the new session" do
      {:ok, _old_session} = Sessions.start_new()

      attrs = %{temperature: 100.0, fan_speed: 0.5, target_temperature: 110.0}
      {:ok, state_before} = States.create_state(attrs)

      {:ok, new_session} = Sessions.start_new()
      {:ok, state_after} = States.create_state(attrs)

      assert state_before.session_id != new_session.id
      assert state_after.session_id == new_session.id
    end
  end
end
