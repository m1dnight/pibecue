defmodule Barbecue.IO.Fanspeed.RealTest do
  use ExUnit.Case, async: true

  alias Barbecue.IO.Fanspeed.Real

  describe "calculate_rpm/1" do
    # An empty buffer means no measurements have come in yet, so the
    # reported RPM is zero.
    test "returns 0.0 for an empty list" do
      assert Real.calculate_rpm([]) == 0.0
    end

    # With a single sample the median is just that sample.
    test "returns the single value for a one-element list" do
      assert Real.calculate_rpm([2500.0]) == 2500.0
    end

    # For odd-length lists the median is the middle value.
    test "returns the middle value for an odd-length list" do
      assert Real.calculate_rpm([1000.0, 2000.0, 3000.0]) == 2000.0
    end

    # For even-length lists the median is the average of the two middle values.
    test "returns the average of the two middle values for an even-length list" do
      assert Real.calculate_rpm([1000.0, 2000.0, 3000.0, 4000.0]) == 2500.0
    end

    # The function must sort internally so callers don't have to maintain
    # ordering — buffers are prepended-to without sorting.
    test "is order-independent (sorts internally)" do
      assert Real.calculate_rpm([3000.0, 1000.0, 2000.0]) == 2000.0
      assert Real.calculate_rpm([2000.0, 3000.0, 1000.0]) == 2000.0
    end

    # A single outlier in a buffer of clean samples must NOT move the median,
    # which is the whole reason we use median over mean.
    test "rejects a single high outlier" do
      samples = [4000.0, 4000.0, 4000.0, 4000.0, 9999.0]
      assert Real.calculate_rpm(samples) == 4000.0
    end
  end
end
