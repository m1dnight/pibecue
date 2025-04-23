defmodule Barbecue.Repo.Migrations.SystemState do
  use Ecto.Migration

  def change do
    create table(:system_state) do
      add(:temperature, :float)
      add(:fan_speed, :float)
      add(:target_temperature, :float)
      timestamps()
    end
  end
end
