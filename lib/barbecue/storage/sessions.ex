defmodule Barbecue.Storage.Sessions do
  @moduledoc """
  CRUD and lookup helpers for cooking sessions.
  """

  import Ecto.Query, warn: false
  alias Barbecue.Repo
  alias Barbecue.Storage.Session

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

  ############################################################
  #                          Helpers                         #
  ############################################################

  # Plain query for the most recent session, without wrapping in a transaction.
  @spec latest() :: Session.t() | nil
  defp latest do
    Repo.one(from(s in Session, order_by: [desc: s.id], limit: 1))
  end
end
