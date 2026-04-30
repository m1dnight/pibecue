defmodule Barbecue.Storage.State do
  @moduledoc """
  Schema for a single system measurement (temperature, fan speed, target).
  Each measurement belongs to exactly one `Barbecue.Storage.Session`.
  """

  use Ecto.Schema
  use TypedEctoSchema

  alias Barbecue.Storage.{Session, State}

  import Ecto.Changeset

  typed_schema "system_state" do
    field(:temperature, :float)
    field(:fan_speed, :float)
    field(:target_temperature, :float)
    belongs_to(:session, Session)
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(State.t(), map()) :: Ecto.Changeset.t()
  def changeset(system_state, attrs) do
    system_state
    |> cast(attrs, [:temperature, :fan_speed, :target_temperature, :session_id])
    |> validate_required([:temperature, :fan_speed, :target_temperature, :session_id])
    |> assoc_constraint(:session)
  end
end
