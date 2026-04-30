defmodule BarbecueWeb.Live.Temperature do
  @moduledoc """
  Display helpers for temperature values on the dashboard.
  """

  # Distance from target where the display flips color (deg C).
  @zone_close 5
  @zone_medium 15

  @doc """
  Formats a temperature delta with an explicit sign.

  ## Examples

      iex> BarbecueWeb.Live.Temperature.format_delta(2.5)
      "+2.5°C"

      iex> BarbecueWeb.Live.Temperature.format_delta(-3.0)
      "-3.0°C"

      iex> BarbecueWeb.Live.Temperature.format_delta(0.0)
      "0.0°C"
  """
  @spec format_delta(float()) :: String.t()
  def format_delta(delta) when delta > 0, do: "+#{Float.round(delta, 1)}°C"
  def format_delta(delta), do: "#{Float.round(delta, 1)}°C"

  @doc """
  Tailwind text-color class based on how close `temperature` is to `target`.

  Returns a neutral color when no target has been set (target == 0.0).

  ## Examples

      iex> BarbecueWeb.Live.Temperature.zone_color(110.0, 110.0)
      "text-emerald-600"

      iex> BarbecueWeb.Live.Temperature.zone_color(120.0, 110.0)
      "text-amber-500"

      iex> BarbecueWeb.Live.Temperature.zone_color(150.0, 110.0)
      "text-rose-600"

      iex> BarbecueWeb.Live.Temperature.zone_color(20.0, 0.0)
      "text-slate-700"
  """
  @spec zone_color(float(), float()) :: String.t()
  def zone_color(_temperature, +0.0), do: "text-slate-700"

  def zone_color(temperature, target) do
    cond do
      abs(temperature - target) <= @zone_close -> "text-emerald-600"
      abs(temperature - target) <= @zone_medium -> "text-amber-500"
      true -> "text-rose-600"
    end
  end
end
