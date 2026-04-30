defmodule BarbecueWeb.Live.Chart do
  @moduledoc """
  Builds inline responsive SVG line plots for the dashboard.
  """

  alias Contex.{Dataset, LinePlot, Plot, TimeScale}

  # Pixel-space dimensions used for the SVG viewBox. The rendered image
  # scales to its container via the responsive-svg post-processing.
  @width 1000
  @height 300

  # Extra right padding (in viewBox units) so the last x-axis tick label
  # doesn't get clipped at the SVG edge.
  @right_padding 40

  # Plot-area bounds within the SVG, derived from Contex's defaults for a
  # 1000x300 LinePlot. The right edge equals the latest measurement because
  # we truncate the x-scale's nice_domain.
  @plot_right 990
  @plot_top 10
  @plot_bottom 230

  @doc """
  Builds an inline responsive SVG line plot from `session_data`.

  `keys` are the series to plot (each must be present as a string-keyed
  field on every data point). `label` is the y-axis label, and `palette`
  is a list of hex color strings (no `#`) — one per key.

  Returns an empty safe value when `session_data` is empty.
  """
  @spec build([map()], [String.t()], String.t(), [String.t()]) :: Phoenix.HTML.safe()
  def build([], _keys, _label, _palette), do: Phoenix.HTML.raw("")

  def build(session_data, keys, label, palette) do
    sorted = Enum.sort_by(session_data, & &1.time, {:asc, DateTime})

    Plot.new(build_dataset(sorted, keys), LinePlot, @width, @height, options(sorted, keys, palette))
    |> Plot.axis_labels("", label)
    |> Plot.to_svg()
    |> post_process()
  end

  ############################################################
  #                          Helpers                         #
  ############################################################

  # Builds a Contex Dataset from session bucket maps (already sorted).
  @spec build_dataset([map()], [String.t()]) :: Dataset.t()
  defp build_dataset(session_data, keys) do
    rows = Enum.map(session_data, &to_chart_row/1)
    Dataset.new(rows, ["time" | keys])
  end

  # Converts a bucket map (atom keys) to chart-row format (string keys).
  @spec to_chart_row(map()) :: %{String.t() => term()}
  defp to_chart_row(d) do
    %{
      "time" => d.time,
      "temperature" => d.temperature,
      "fan_speed" => d.fan_speed,
      "target_temperature" => d.target_temperature
    }
  end

  # Builds the Contex chart options with a TimeScale that spans exactly
  # from the first to the last measurement.
  @spec options([map()], [String.t()], [String.t()]) :: keyword()
  defp options([%{time: first} | _] = sorted, keys, palette) do
    %{time: last} = List.last(sorted)

    [
      custom_x_formatter: fn x -> Timex.format!(x, "{h24}:{m}") end,
      custom_x_scale: exact_time_scale(first, last),
      colour_palette: palette,
      mapping: %{x_col: "time", y_cols: keys},
      legend_setting: :legend_none,
      smoothed: false
    ]
  end

  # Builds a TimeScale that spans exactly `[first, last]`. Contex's nice/1
  # would otherwise round both edges out to the nearest tick boundary; we
  # override `nice_domain` to keep the chart aligned with the actual data.
  # `display_count` is recomputed so ticks past `last` aren't generated.
  @spec exact_time_scale(DateTime.t(), DateTime.t()) :: TimeScale.t()
  defp exact_time_scale(first, last) do
    scale = TimeScale.new() |> TimeScale.domain(first, last)
    interval_ms = elem(scale.tick_interval, 2)
    count = div(DateTime.diff(last, first, :millisecond), interval_ms)

    struct(scale, nice_domain: {first, last}, display_count: count)
  end

  # Pads the SVG viewBox on the right (so trailing tick labels don't clip)
  # and appends a dotted vertical line at the right edge to mark "now".
  @spec post_process(Phoenix.HTML.safe()) :: Phoenix.HTML.safe()
  defp post_process({:safe, iodata}) do
    iodata
    |> IO.iodata_to_binary()
    |> pad_viewbox_right()
    |> append_now_marker()
    |> Phoenix.HTML.raw()
  end

  # Extends the existing viewBox attribute by @right_padding units on the right.
  @spec pad_viewbox_right(String.t()) :: String.t()
  defp pad_viewbox_right(svg) do
    Regex.replace(
      ~r/viewBox="(\d+) (\d+) (\d+) (\d+)"/,
      svg,
      fn _, x, y, w, h ->
        new_w = String.to_integer(w) + @right_padding
        ~s|viewBox="#{x} #{y} #{new_w} #{h}"|
      end
    )
  end

  # Appends a dotted vertical line at the right edge of the plot area to
  # mark the latest measurement.
  @spec append_now_marker(String.t()) :: String.t()
  defp append_now_marker(svg) do
    line =
      ~s|<line x1="#{@plot_right}" y1="#{@plot_top}" x2="#{@plot_right}" y2="#{@plot_bottom}" stroke="#94a3b8" stroke-width="1" stroke-dasharray="4 3" />|

    String.replace(svg, "</svg>", "#{line}</svg>")
  end
end
