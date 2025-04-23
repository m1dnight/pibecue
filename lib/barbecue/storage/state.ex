defmodule Barbecue.Storage.State do
  @moduledoc """
  Schema for a fan speed measurement.
  """
  use Ecto.Schema
  use TypedEctoSchema

  alias Barbecue.Storage.State

  import Ecto.Changeset

  typed_schema "system_state" do
    field(:temperature, :float)
    field(:fan_speed, :float)
    field(:target_temperature, :float)
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(State.t(), map()) :: Ecto.Changeset.t()
  def changeset(system_state, attrs) do
    system_state
    |> cast(attrs, [:temperature, :fan_speed, :target_temperature])
    |> validate_required([:temperature, :fan_speed, :target_temperature])
  end
end
