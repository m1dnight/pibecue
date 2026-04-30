defmodule BarbecueWeb.Live.ChartTest do
  use ExUnit.Case, async: true

  alias BarbecueWeb.Live.Chart

  describe "build/4" do
    # An empty data set should not produce any chart markup so the page can
    # render the empty state instead.
    test "returns a safe empty value for empty session_data" do
      assert Chart.build([], ["temperature"], "°C", ["10b981"]) == Phoenix.HTML.raw("")
    end

    # Non-empty data must produce a Phoenix.HTML safe iolist containing an
    # SVG root element so the template can interpolate it directly.
    test "produces a safe SVG for non-empty session_data" do
      result = Chart.build(sample_data(), ["temperature"], "°C", ["10b981"])

      assert match?({:safe, _}, result)
      assert rendered(result) =~ "<svg"
    end

    # The SVG must have a viewBox so it scales with the surrounding container
    # instead of using fixed pixel dimensions.
    test "the rendered SVG has a viewBox for responsive scaling" do
      result = Chart.build(sample_data(), ["temperature"], "°C", ["10b981"])
      svg = rendered(result)

      assert svg =~ "viewBox="
    end

    # The chart should render multiple series when multiple keys are passed.
    test "handles multiple series" do
      result =
        Chart.build(
          sample_data(),
          ["temperature", "target_temperature"],
          "°C",
          ["10b981", "be123c"]
        )

      assert match?({:safe, _}, result)
    end
  end

  defp sample_data do
    base = ~U[2026-04-30 10:00:00Z]

    for offset <- 0..5 do
      %{
        time: DateTime.add(base, offset * 10, :second),
        temperature: 100.0 + offset,
        fan_speed: 2000.0 + offset * 100,
        target_temperature: 110.0
      }
    end
  end

  defp rendered({:safe, iodata}), do: IO.iodata_to_binary(iodata)
end
