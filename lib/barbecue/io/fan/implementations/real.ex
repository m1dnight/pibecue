defmodule Barbecue.IO.Fanspeed.Real do
  use GenServer
  require Logger
  alias Barbecue.IO.Fanspeed.Real, as: Fanspeed
  alias Circuits.GPIO

  # gpio pin to set interrupts for pwm counter
  @gpio_rpm "GPIO24"
  @gpio_pwm_control "GPIO16"
  @gpio_pwm_signal 12

  defstruct rpm_gpio: nil, pwm_gpio: nil, rpms: [], last_timestamp: 0

  # @behaviour Barbecue.IO.Fanspeed

  def start_link(args \\ []) do
    Logger.debug("#{__MODULE__} start_link #{inspect(args)}")
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  ############################################################
  #                           Api                            #
  ############################################################

  @doc """
  Returns the fan speed in RPM.
  """
  def speed() do
    GenServer.call(__MODULE__, :speed)
  end

  @doc """
  Set the fan speed in percentage.
  """
  def set_speed(speed) do
    GenServer.call(__MODULE__, {:speed, speed})
  end

  ############################################################
  #                GenServer callbacks                       #
  ############################################################

  @impl true
  def init(args) do
    Logger.debug("#{__MODULE__} init #{inspect(args)}")

    {:ok, rpm_gpio} = configure_rpm_interrupts(@gpio_rpm)
    {:ok, pwm_gpio} = configure_pwm(@gpio_pwm_control, @gpio_pwm_signal)

    state = %Fanspeed{rpm_gpio: rpm_gpio, pwm_gpio: pwm_gpio}

    set_speed(state, 0.0)

    {:ok, state}
  end

  @impl true
  def handle_call(:speed, _from, state) do
    {:reply, calculate_rpm(state.rpms), state}
  end

  def handle_call({:speed, percent}, _from, state) do
    set_speed(state, percent)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:circuits_gpio, _, nanoseconds, _value}, state) do
    # the fan is rated for 10k rpm at most, so it can only send a pulse every
    # 6_000_000 nanoseconds.
    dt = nanoseconds - state.last_timestamp

    if dt < 2_000_000 do
      {:noreply, %{state | last_timestamp: nanoseconds}}
    else
      frequency = 1 / dt
      rpm = frequency / 2 * 60 * 1_000_000_000

      rpms = Enum.take([rpm | state.rpms], 10)
      {:noreply, %{state | last_timestamp: nanoseconds, rpms: rpms}}
    end
  end

  ############################################################
  #                           Helpers                        #
  ############################################################

  @spec calculate_rpm([float()]) :: float()
  defp calculate_rpm(rpms) do
    case rpms do
      [] ->
        0.0

      rpms ->
        Enum.sum(rpms) / Enum.count(rpms)
    end
  end

  @spec set_speed(term(), float()) :: :ok
  defp set_speed(state, percent) do
    GPIO.write(state.pwm_gpio, 1)

    # set the pwm value
    Pigpiox.Pwm.gpio_pwm(@gpio_pwm_signal, trunc(255 * percent))
    :ok
  end

  @spec configure_rpm_interrupts(String.t()) :: {:ok, term()}
  defp configure_rpm_interrupts(gpio_pin) do
    # watch the gpio pin for fan speed events
    {:ok, gpio} = GPIO.open(gpio_pin, :input)
    :ok = GPIO.set_pull_mode(gpio, :pullup)
    :ok = GPIO.set_interrupts(gpio, :falling)
    {:ok, gpio}
  end

  @spec configure_pwm(String.t(), integer()) :: {:ok, term()}
  defp configure_pwm(gpio_pwm_control, gpio_pwm_signal) do
    # set the control pin to 1 for controlling the speed
    {:ok, gpio_pwm_control} = GPIO.open(gpio_pwm_control, :output)
    GPIO.write(gpio_pwm_control, 1)

    # set the pwm value
    Pigpiox.Pwm.gpio_pwm(gpio_pwm_signal, trunc(255 * 0.1))
    {:ok, gpio_pwm_control}
  end
end
