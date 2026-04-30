defmodule BarbecueWeb.Sessions do
  @moduledoc """
  Live page listing all cooking sessions with their start/end timestamps,
  duration, and measurement count.
  """

  use BarbecueWeb, :live_view

  alias Barbecue.Storage.Sessions

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :sessions, Sessions.list_with_stats())}
  end

  @impl true
  def handle_event("start-new-session", _params, socket) do
    {:ok, _} = Sessions.start_new()
    {:noreply, assign(socket, :sessions, Sessions.list_with_stats())}
  end

  ############################################################
  #                    Template helpers                      #
  ############################################################

  @doc """
  Formats a `DateTime` for the sessions table, or returns "—" for nil.

  ## Examples

      iex> BarbecueWeb.Sessions.format_time(~U[2026-04-30 18:31:00Z])
      "2026-04-30 18:31"

      iex> BarbecueWeb.Sessions.format_time(nil)
      "—"
  """
  @spec format_time(DateTime.t() | nil) :: String.t()
  def format_time(nil), do: "—"
  def format_time(dt), do: Timex.format!(dt, "{YYYY}-{0M}-{0D} {h24}:{m}")

  @doc """
  Formats a duration (in seconds) as a human-readable string.

  ## Examples

      iex> BarbecueWeb.Sessions.format_duration(0)
      "0s"

      iex> BarbecueWeb.Sessions.format_duration(45)
      "45s"

      iex> BarbecueWeb.Sessions.format_duration(125)
      "2m 5s"

      iex> BarbecueWeb.Sessions.format_duration(3725)
      "1h 2m 5s"

      iex> BarbecueWeb.Sessions.format_duration(nil)
      "—"
  """
  @spec format_duration(non_neg_integer() | nil) :: String.t()
  def format_duration(nil), do: "—"

  def format_duration(seconds) when is_integer(seconds) do
    h = div(seconds, 3600)
    m = div(rem(seconds, 3600), 60)
    s = rem(seconds, 60)

    [{h, "h"}, {m, "m"}, {s, "s"}]
    |> Enum.drop_while(fn {n, _} -> n == 0 end)
    |> case do
      [] -> "0s"
      parts -> Enum.map_join(parts, " ", fn {n, u} -> "#{n}#{u}" end)
    end
  end
end
