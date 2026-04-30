defmodule Barbecue.Repo.Migrations.CreateSessionsTable do
  use Ecto.Migration

  def change do
    # Drop the placeholder `session` integer column added by the previous
    # migration; the real association lives in `session_id` below.
    drop index(:system_state, [:session])

    alter table(:system_state) do
      remove :session
    end

    create table(:sessions) do
      timestamps(type: :utc_datetime)
    end

    alter table(:system_state) do
      add :session_id, references(:sessions, on_delete: :nothing)
    end

    create index(:system_state, [:session_id])

    # Backfill: ensure there's always at least one session, and link any
    # pre-existing measurements to it so the FK is non-null going forward.
    flush()

    execute(
      "INSERT INTO sessions (inserted_at, updated_at) VALUES (datetime('now'), datetime('now'))",
      "DELETE FROM sessions"
    )

    execute(
      "UPDATE system_state SET session_id = (SELECT id FROM sessions ORDER BY id LIMIT 1) WHERE session_id IS NULL",
      "UPDATE system_state SET session_id = NULL"
    )
  end
end
