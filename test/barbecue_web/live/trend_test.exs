defmodule BarbecueWeb.Live.TrendTest do
  use ExUnit.Case, async: true

  alias BarbecueWeb.Live.Trend

  describe "compute/2" do
    # Returns :flat when no previous reading exists, e.g. on first sample after mount.
    test "returns :flat when previous is nil" do
      assert Trend.compute(nil, 100.0) == :flat
    end

    # Returns :up when the new reading rises by more than the dead band.
    test "returns :up for a rise larger than the threshold" do
      assert Trend.compute(99.0, 100.0) == :up
    end

    # Returns :down when the new reading falls by more than the dead band.
    test "returns :down for a drop larger than the threshold" do
      assert Trend.compute(100.0, 99.0) == :down
    end

    # Returns :flat for changes inside the dead band to avoid flicker on noisy sensors.
    test "returns :flat for tiny changes inside the dead band" do
      assert Trend.compute(100.0, 100.1) == :flat
      assert Trend.compute(100.1, 100.0) == :flat
    end

    # Returns :flat when the reading is exactly equal to the previous one.
    test "returns :flat for an unchanged reading" do
      assert Trend.compute(100.0, 100.0) == :flat
    end
  end

  describe "icon/1" do
    # Maps each direction to its corresponding heroicon name.
    test "returns the correct heroicon name per direction" do
      assert Trend.icon(:up) == "hero-arrow-trending-up"
      assert Trend.icon(:down) == "hero-arrow-trending-down"
      assert Trend.icon(:flat) == "hero-minus"
    end
  end

  describe "color/1" do
    # Maps each direction to a Tailwind text-color class.
    test "returns the correct color class per direction" do
      assert Trend.color(:up) == "text-rose-500"
      assert Trend.color(:down) == "text-sky-500"
      assert Trend.color(:flat) == "text-slate-400"
    end
  end
end
