defmodule BarbecueWeb.Live.Chart do
  @moduledoc """
  Builds inline responsive SVG line plots for the dashboard.
  """

  alias Contex.{Dataset, LinePlot, Plot, TimeScale}

  # Pixel-space dimensions used for the SVG viewBox; the rendered image
  # scales to its container thanks to the responsive-svg post-processing.
  @width 1000
  @height 300

  # Extra right padding (in viewBox units) so the last x-axis tick label
  # doesn't get clipped at the SVG edge.
  @right_padding 60

  # Plot-area bounds within the SVG, derived from Contex's defaults for a
  # 1000x300 LinePlot. Used to position the "current time" indicator at
  # the right edge of the chart (which now equals the latest measurement
  # because we truncate the x-scale's nice_domain).
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
    |> responsive_svg()
    |> inject_now_marker(@plot_right)
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

  # Builds the Contex chart options. Provides an explicit TimeScale spanning
  # the data's time range; Contex's `nice/1` rounds this to clean tick
  # boundaries (e.g. 5-minute intervals).
  @spec options([map()], [String.t()], [String.t()]) :: keyword()
  defp options(sorted, keys, palette) do
    base = [
      custom_x_formatter: fn x -> Timex.format!(x, "{h24}:{m}") end,
      colour_palette: palette,
      mapping: %{x_col: "time", y_cols: keys},
      legend_setting: :legend_none,
      smoothed: false
    ]

    IO.inspect hd(sorted)
    IO.inspect List.last(sorted)
    case sorted do
      [] ->
        base

      [%{time: first} | _] = data ->
        %{time: last} = List.last(data)
        Keyword.put(base, :custom_x_scale, truncated_time_scale(first, last))
    end
  end

  # Builds a TimeScale whose left edge is rounded down to a tick boundary
  # (Contex's default behavior) but whose right edge is truncated back to
  # `last` — so the chart ends exactly at the latest measurement instead of
  # extending out to the next 5-minute mark. `display_count` is recomputed
  # so the now-removed trailing tick isn't generated.
  @spec truncated_time_scale(DateTime.t(), DateTime.t()) :: TimeScale.t()
  defp truncated_time_scale(first, last) do
    scale = TimeScale.new() |> TimeScale.domain(first, last)
    {nice_min, _} = scale.nice_domain
    interval_ms = elem(scale.tick_interval, 2)
    width_ms = DateTime.diff(last, nice_min, :millisecond)
    count = div(width_ms, interval_ms)

    struct(scale, nice_domain: {nice_min, last}, display_count: count)
  end

  # Post-processes a Contex SVG so it scales to its container.
  @spec responsive_svg(Phoenix.HTML.safe() | binary()) :: Phoenix.HTML.safe()
  defp responsive_svg({:safe, iodata}), do: responsive_svg(IO.iodata_to_binary(iodata))

  defp responsive_svg(svg) when is_binary(svg) do
    svg
    |> String.replace(~r/<svg([^>]*?)>/s, &make_svg_responsive/1)
    |> Phoenix.HTML.raw()
  end

  # Rewrites a single <svg ...> opening tag to use viewBox + 100% dimensions
  # and extends the viewBox horizontally so edge tick labels aren't clipped.
  @spec make_svg_responsive(String.t()) :: String.t()
  defp make_svg_responsive(tag) do
    if String.contains?(tag, "viewBox") do
      pad_viewbox_right(tag, @right_padding)
    else
      w = String.to_integer(extract_attr(tag, "width") || "#{@width}")
      h = extract_attr(tag, "height") || "#{@height}"

      tag
      |> String.replace(~r/width="\d+"/, ~s|width="100%"|)
      |> String.replace(~r/height="\d+"/, ~s|height="100%"|)
      |> String.replace(
        ~r/<svg/,
        ~s|<svg viewBox="0 0 #{w + @right_padding} #{h}" preserveAspectRatio="xMidYMid meet" style="display:block"|
      )
    end
  end

  # Extends an existing viewBox attribute by `padding` units on the right.
  @spec pad_viewbox_right(String.t(), non_neg_integer()) :: String.t()
  defp pad_viewbox_right(tag, padding) do
    Regex.replace(
      ~r/viewBox="(\d+) (\d+) (\d+) (\d+)"/,
      tag,
      fn _, x, y, w, h ->
        new_w = String.to_integer(w) + padding
        ~s|viewBox="#{x} #{y} #{new_w} #{h}"|
      end
    )
  end

  # Extracts a numeric attribute value from an SVG opening tag.
  @spec extract_attr(String.t(), String.t()) :: String.t() | nil
  defp extract_attr(tag, attr) do
    case Regex.run(~r/#{attr}="(\d+)"/, tag) do
      [_, value] -> value
      _ -> nil
    end
  end

  # Injects a dotted vertical line at `x` to mark "now" — the latest
  # measurement's position within the chart's nice-rounded x-axis.
  @spec inject_now_marker(Phoenix.HTML.safe(), float()) :: Phoenix.HTML.safe()
  defp inject_now_marker({:safe, svg}, x) do
    line =
      ~s|<line x1="#{x}" y1="#{@plot_top}" x2="#{x}" y2="#{@plot_bottom}" stroke="#94a3b8" stroke-width="1" stroke-dasharray="4 3" />|

    svg = svg |> IO.iodata_to_binary() |> String.replace("</svg>", "#{line}</svg>")
    Phoenix.HTML.raw(svg)
  end
end
