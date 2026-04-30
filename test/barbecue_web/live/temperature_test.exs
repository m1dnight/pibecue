defmodule BarbecueWeb.Live.TemperatureTest do
  use ExUnit.Case, async: true

  alias BarbecueWeb.Live.Temperature

  describe "format_delta/1" do
    # Positive deltas should be displayed with an explicit + sign so the user
    # can distinguish "above target" from "below target" at a glance.
    test "prefixes positive deltas with +" do
      assert Temperature.format_delta(2.5) == "+2.5°C"
      assert Temperature.format_delta(0.1) == "+0.1°C"
    end

    # Negative deltas keep their natural minus sign from float printing.
    test "negative deltas keep their minus sign" do
      assert Temperature.format_delta(-3.0) == "-3.0°C"
    end

    # A zero delta is treated as non-positive, so no leading + is added.
    test "zero delta does not get a + prefix" do
      assert Temperature.format_delta(0.0) == "0.0°C"
    end

    # All values are rounded to one decimal place to keep the UI compact.
    test "rounds to one decimal place" do
      assert Temperature.format_delta(2.66) == "+2.7°C"
      assert Temperature.format_delta(-2.34) == "-2.3°C"
    end
  end

  describe "zone_color/2" do
    # When the user hasn't set a target, the display uses a neutral color
    # rather than implying we're "off target."
    test "returns a neutral color when target is 0.0" do
      assert Temperature.zone_color(20.0, 0.0) == "text-slate-700"
    end

    # Within ±5°C of target, the controller is on track — green.
    test "returns emerald inside the close band" do
      assert Temperature.zone_color(110.0, 110.0) == "text-emerald-600"
      assert Temperature.zone_color(115.0, 110.0) == "text-emerald-600"
      assert Temperature.zone_color(105.0, 110.0) == "text-emerald-600"
    end

    # Beyond ±5 but within ±15, the controller is recovering — amber warning.
    test "returns amber inside the medium band" do
      assert Temperature.zone_color(120.0, 110.0) == "text-amber-500"
      assert Temperature.zone_color(100.0, 110.0) == "text-amber-500"
    end

    # Beyond ±15 the situation is bad — red alert.
    test "returns rose for far-from-target temperatures" do
      assert Temperature.zone_color(150.0, 110.0) == "text-rose-600"
      assert Temperature.zone_color(50.0, 110.0) == "text-rose-600"
    end

    # Boundary values land in the more severe band.
    test "deltas at the band boundaries fall into the closer (lower) band" do
      assert Temperature.zone_color(115.0, 110.0) == "text-emerald-600"
      assert Temperature.zone_color(125.0, 110.0) == "text-amber-500"
    end
  end
end
