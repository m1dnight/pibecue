defmodule Barbecue.Storage.Sessions do
  @moduledoc """
  CRUD and lookup helpers for cooking sessions.
  """

  import Ecto.Query, warn: false
  alias Barbecue.Repo
  alias Barbecue.Storage.{Session, State}

  @typedoc """
  A session row with derived statistics from its measurements.
  `started_at`, `ended_at`, and `duration_seconds` are nil when the session
  has no measurements yet.
  """
  @type stats :: %{
          id: integer(),
          started_at: DateTime.t() | nil,
          ended_at: DateTime.t() | nil,
          duration_seconds: non_neg_integer() | nil,
          measurement_count: non_neg_integer()
        }

  @doc """
  Returns the most recently started session, or `nil` if none exist.

  Runs inside a transaction so that the read sees a consistent snapshot
  (relevant when paired with `ensure_current/0` under contention).
  """
  @spec current() :: Session.t() | nil
  def current do
    {:ok, result} = Repo.transaction(fn -> latest() end)
    result
  end

  @doc """
  Inserts a new session and returns it.
  """
  @spec start_new() :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def start_new do
    %Session{}
    |> Session.changeset()
    |> Repo.insert()
  end

  @doc """
  Returns the current session, creating one if the table is empty.

  Runs inside an `:immediate` transaction so the check-and-insert pair is
  atomic — two concurrent callers on an empty table cannot both succeed
  in inserting a new session.
  """
  @spec ensure_current() :: Session.t()
  def ensure_current do
    {:ok, session} =
      Repo.transaction(
        fn ->
          case latest() do
            nil ->
              {:ok, new} = start_new()
              new

            existing ->
              existing
          end
        end,
        mode: :immediate
      )

    session
  end

  @doc """
  Lists all sessions, newest first.
  """
  @spec list() :: [Session.t()]
  def list do
    Repo.all(from(s in Session, order_by: [desc: s.id]))
  end

  @doc """
  Returns the `inserted_at` of the current session's earliest measurement,
  or `nil` when no session exists yet or it has no measurements.
  """
  @spec current_started_at() :: DateTime.t() | nil
  def current_started_at do
    case current() do
      nil ->
        nil

      session ->
        Repo.one(
          from(st in State,
            where: st.session_id == ^session.id,
            select: type(min(st.inserted_at), :utc_datetime)
          )
        )
    end
  end

  @doc """
  Lists all sessions with derived `started_at`, `ended_at`, `duration_seconds`,
  and `measurement_count`. Newest first.

  `started_at`/`ended_at` come from the min/max of the linked measurements'
  `inserted_at`. Sessions with no measurements get nil for time fields.
  """
  @spec list_with_stats() :: [stats()]
  def list_with_stats do
    from(s in Session,
      left_join: st in State,
      on: st.session_id == s.id,
      group_by: s.id,
      order_by: [desc: s.id],
      select: %{
        id: s.id,
        started_at: type(min(st.inserted_at), :utc_datetime),
        ended_at: type(max(st.inserted_at), :utc_datetime),
        measurement_count: count(st.id)
      }
    )
    |> Repo.all()
    |> Enum.map(&with_duration/1)
  end

  ############################################################
  #                          Helpers                         #
  ############################################################

  # Plain query for the most recent session, without wrapping in a transaction.
  @spec latest() :: Session.t() | nil
  defp latest do
    Repo.one(from(s in Session, order_by: [desc: s.id], limit: 1))
  end

  # Adds a `duration_seconds` field to a stats row.
  @spec with_duration(map()) :: stats()
  defp with_duration(%{started_at: nil} = row), do: Map.put(row, :duration_seconds, nil)

  defp with_duration(%{started_at: s, ended_at: e} = row) do
    Map.put(row, :duration_seconds, DateTime.diff(e, s, :second))
  end
end
