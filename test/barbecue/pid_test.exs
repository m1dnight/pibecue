defmodule Barbecue.PIDTest do
  use ExUnit.Case, async: true

  alias Barbecue.PID

  describe "set_mode/2" do
    # Switching to :aggressive should swap in the larger gain coefficients so
    # the controller responds harder to error.
    test "applies aggressive coefficients" do
      result = PID.set_mode(%PID{}, :aggressive)

      assert result.kp == 2.0
      assert result.ki == 0.005
      assert result.kd == 5.0
    end

    # Switching to :slow should swap in the smaller gain coefficients for
    # gentler control near the target.
    test "applies slow coefficients" do
      result = PID.set_mode(%PID{}, :slow)

      assert result.kp == 1.0
      assert result.ki == 0.01
      assert result.kd == 0.1
    end

    # An unknown mode should leave the state untouched rather than crash, so
    # callers can pass arbitrary atoms safely.
    test "leaves state unchanged for an unknown mode" do
      original = %PID{kp: 9.9, ki: 9.9, kd: 9.9}

      assert PID.set_mode(original, :unknown) == original
    end

    # The accumulator state (integral, previous_error) must be preserved
    # across mode changes so the controller doesn't lose track mid-run.
    test "preserves integral and previous_error" do
      state = %PID{integral: 5.0, previous_error: 1.5}
      result = PID.set_mode(state, :aggressive)

      assert result.integral == 5.0
      assert result.previous_error == 1.5
    end
  end

  describe "update/3" do
    # When the temperature is at or above target, the fan should be off and
    # the integral reset so wind-up doesn't overshoot.
    test "returns 0.0 fan speed and resets integral when over target" do
      state = %PID{integral: 50.0}

      {new_state, fan_speed} = PID.update(state, 110.0, 100.0)

      assert fan_speed == 0.0
      assert new_state.integral == 0.0
      # negative because target - temperature
      assert new_state.previous_error == -10.0
    end

    # Below target, the fan should turn on. The exact speed depends on the
    # gains, but the result must be a valid duty fraction.
    test "returns a valid duty (0.0..1.0) when below target" do
      state = %PID{}

      {_new_state, fan_speed} = PID.update(state, 90.0, 100.0)

      assert fan_speed >= 0.0
      assert fan_speed <= 1.0
    end

    # The integral term must accumulate the error across successive calls so
    # steady-state offsets are eventually corrected.
    test "accumulates error in the integral over successive updates" do
      state = %PID{}

      {state, _} = PID.update(state, 90.0, 100.0)
      assert state.integral == 10.0

      {state, _} = PID.update(state, 92.0, 100.0)
      assert state.integral == 18.0
    end

    # previous_error must always reflect the most recent error so the
    # derivative term is computed correctly on the next iteration.
    test "stores the most recent error in previous_error" do
      {state, _} = PID.update(%PID{}, 90.0, 100.0)
      assert state.previous_error == 10.0
    end

    # The fan output is clamped so an extreme error can't produce an
    # impossible duty value.
    test "clamps the fan speed to at most 1.0" do
      # huge error + huge integral builds up quickly
      state = %PID{kp: 100.0, ki: 1.0, integral: 1000.0}

      {_new_state, fan_speed} = PID.update(state, 0.0, 100.0)

      assert fan_speed == 1.0
    end
  end
end
