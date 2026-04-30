defmodule Barbecue.Storage.Session do
  @moduledoc """
  Schema representing one cooking session.

  All measurements (`Barbecue.Storage.State`) belong to a session via the
  `session_id` foreign key. The "current" session is the one with the
  highest id; a new session is started by inserting a new row here.
  """

  use Ecto.Schema
  use TypedEctoSchema

  alias Barbecue.Storage.{Session, State}

  import Ecto.Changeset

  typed_schema "sessions" do
    has_many(:measurements, State, foreign_key: :session_id)
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(Session.t(), map()) :: Ecto.Changeset.t()
  def changeset(session, attrs \\ %{}) do
    session
    |> cast(attrs, [])
  end
end
