defmodule Barbecue.ControllerTest do
  # async: false because the Controller, Monitor, and Mock GenServers are
  # singletons started by the application supervisor.
  use ExUnit.Case, async: false

  alias Barbecue.{Controller, Monitor}
  alias Phoenix.PubSub

  setup do
    # Silence the periodic monitor so it doesn't broadcast system_state
    # messages and trigger spurious controller activity mid-test.
    Monitor.stop()

    # Establish a known starting state.
    Controller.set_target_temperature(0.0)
    Controller.start()

    on_exit(fn ->
      Controller.set_target_temperature(0.0)
      Controller.start()
      Monitor.start()
    end)

    :ok
  end

  describe "set_target_temperature/1 & target_temperature/0" do
    # The target temperature must round-trip through the GenServer so the UI
    # can read back what it set.
    test "round-trip: written value is readable" do
      Controller.set_target_temperature(115.5)
      assert Controller.target_temperature() == 115.5
    end
  end

  describe "start/0, stop/0, on?/0" do
    # After construction the controller is enabled, otherwise the system
    # would never react to temperature changes after boot.
    test "is enabled by default" do
      assert Controller.on?()
    end

    # stop must disable the controller so manual override of the fan works.
    test "stop disables the controller" do
      Controller.stop()
      refute Controller.on?()
    end

    # start must re-enable a previously stopped controller.
    test "start re-enables the controller" do
      Controller.stop()
      Controller.start()
      assert Controller.on?()
    end
  end

  describe "system_state handling" do
    setup do
      PubSub.subscribe(Barbecue.PubSub, "pid")
      :ok
    end

    # When enabled and below target, an incoming measurement triggers a
    # :pid broadcast carrying the new fan speed for the LiveView.
    test "broadcasts a :pid event when enabled and below target" do
      Controller.set_target_temperature(150.0)
      Controller.start()

      send_system_state(temperature: 100.0, target_temperature: 150.0)

      assert_receive {:pid, fan_speed}
      assert is_float(fan_speed)
      assert fan_speed >= 0.0
    end

    # When the temperature is above target, the PID returns 0.0 fan speed
    # (no need to fan a fire that's already too hot).
    test "broadcasts 0.0 fan speed when temperature is above target" do
      Controller.set_target_temperature(50.0)
      Controller.start()

      send_system_state(temperature: 100.0, target_temperature: 50.0)

      assert_receive {:pid, +0.0}
    end

    # When stopped, the controller must ignore measurements entirely so the
    # fan stays at whatever the user manually set.
    test "ignores system_state messages when disabled" do
      Controller.stop()

      send_system_state(temperature: 100.0, target_temperature: 150.0)

      refute_receive {:pid, _}, 100
    end
  end

  defp send_system_state(opts) do
    PubSub.broadcast(
      Barbecue.PubSub,
      "system_state",
      {:system_state,
       %{
         temperature: Keyword.fetch!(opts, :temperature),
         target_temperature: Keyword.fetch!(opts, :target_temperature),
         fan_speed: Keyword.get(opts, :fan_speed, 0.0)
       }}
    )
  end
end
