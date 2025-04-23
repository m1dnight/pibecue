defmodule Barbecue.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {Phoenix.PubSub, name: Barbecue.PubSub},
        Barbecue.Repo,
        Barbecue.Controller,
        BarbecueWeb.Telemetry,
        BarbecueWeb.Endpoint,
        Barbecue.Monitor
      ] ++ children(target())

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Barbecue.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      Barbecue.IO.Fanspeed.Mock,
      Barbecue.IO.Thermocouple.Mock,
    ]
  end

  def children(_target) do
    [
      Barbecue.IO.Fanspeed.Real,
      Barbecue.IO.Thermocouple.Real,
    ]
  end

  def target() do
    Application.get_env(:barbecue, :target)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BarbecueWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
