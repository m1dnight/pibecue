defmodule BarbecueWeb.Live.Trend do
  @moduledoc """
  Temperature-trend computation and display helpers.
  """

  @typedoc "Direction of recent temperature change."
  @type direction :: :up | :down | :flat

  # Smallest temperature change considered a real trend (deg C).
  @threshold 0.2

  @doc """
  Computes the trend direction from a previous and current temperature reading.

  Returns `:flat` when there is no prior reading or the change is within
  the dead band.

  ## Examples

      iex> BarbecueWeb.Live.Trend.compute(nil, 100.0)
      :flat

      iex> BarbecueWeb.Live.Trend.compute(99.5, 100.0)
      :up

      iex> BarbecueWeb.Live.Trend.compute(100.5, 100.0)
      :down

      iex> BarbecueWeb.Live.Trend.compute(100.0, 100.1)
      :flat
  """
  @spec compute(float() | nil, float()) :: direction()
  def compute(nil, _current), do: :flat

  def compute(previous, current) do
    cond do
      current - previous > @threshold -> :up
      previous - current > @threshold -> :down
      true -> :flat
    end
  end

  @doc "Heroicon name representing the trend direction."
  @spec icon(direction()) :: String.t()
  def icon(:up), do: "hero-arrow-trending-up"
  def icon(:down), do: "hero-arrow-trending-down"
  def icon(:flat), do: "hero-minus"

  @doc "Tailwind text-color class for the trend direction."
  @spec color(direction()) :: String.t()
  def color(:up), do: "text-rose-500"
  def color(:down), do: "text-sky-500"
  def color(:flat), do: "text-slate-400"
end
