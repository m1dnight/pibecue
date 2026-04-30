defmodule Barbecue.Storage.StatesTest do
  use ExUnit.Case, async: true

  alias Barbecue.Storage.States

  describe "bucket_time/2" do
    # A timestamp at the start of a bucket should be returned unchanged.
    test "leaves a timestamp on a bucket boundary alone" do
      dt = ~U[2026-04-30 10:00:00Z]
      assert States.bucket_time(dt, 10) == dt
    end

    # Timestamps inside a bucket should round down to that bucket's start, so
    # measurements are grouped consistently.
    test "truncates a timestamp to the start of its 10-second bucket" do
      assert States.bucket_time(~U[2026-04-30 10:00:07Z], 10) == ~U[2026-04-30 10:00:00Z]
      assert States.bucket_time(~U[2026-04-30 10:00:09.999999Z], 10) == ~U[2026-04-30 10:00:00Z]
      assert States.bucket_time(~U[2026-04-30 10:00:11Z], 10) == ~U[2026-04-30 10:00:10Z]
    end

    # Larger bucket sizes must work the same way.
    test "truncates to one-minute buckets" do
      assert States.bucket_time(~U[2026-04-30 10:00:42Z], 60) == ~U[2026-04-30 10:00:00Z]
      assert States.bucket_time(~U[2026-04-30 10:01:00Z], 60) == ~U[2026-04-30 10:01:00Z]
    end

    # Two timestamps in the same bucket must produce the same result so they
    # can be grouped together by the caller.
    test "two timestamps in the same bucket produce equal results" do
      a = States.bucket_time(~U[2026-04-30 10:00:01Z], 10)
      b = States.bucket_time(~U[2026-04-30 10:00:09Z], 10)

      assert a == b
    end
  end
end
