defmodule Barbecue.Release do
  @moduledoc """
  Runs Ecto migrations at application boot.

  `with_repo/2` starts the repo temporarily, runs migrations, then stops it,
  so this can safely be called before the supervision tree starts the repo
  for normal operation.
  """

  @app :barbecue

  def migrate do
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)
end
