defmodule Barbecue.Repo.Migrations.SessionId do
  use Ecto.Migration

  def change do
    alter table(:system_state) do
      add(:session, :integer, autogenerate: true, default: 0)
    end
    create index(:system_state, [:session])
  end
end
