defmodule Barbecue.IO.Fanspeed.Real do
  use GenServer
  require Logger
  alias Barbecue.IO.Fanspeed.Real, as: Fanspeed
  alias Circuits.GPIO

  @gpio_rpm "GPIO24"
  @gpio_pwm_signal 12
  @pwm_frequency_hz 10_000

  # Reject pulses arriving within this window of the last accepted pulse.
  # 4 ms easily passes a 5k-RPM fan (≈6.7 ms between falling edges) while
  # filtering PWM-induced noise on the tach line.
  @debounce_ns 4_000_000

  # If no tach pulse has arrived for this long, treat the fan as stopped.
  @stale_ns 500_000_000

  @rpm_samples 20

  defstruct rpm_gpio: nil, rpms: [], last_timestamp: nil

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
    Pigpiox.Pwm.hardware_pwm(@gpio_pwm_signal, @pwm_frequency_hz, 0)

    {:ok, %Fanspeed{rpm_gpio: rpm_gpio}}
  end

  @impl true
  def handle_call(:speed, _from, state) do
    {:reply, current_rpm(state), state}
  end

  def handle_call({:speed, percent}, _from, state) do
    apply_speed(percent)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:circuits_gpio, _, nanoseconds, _value}, %{last_timestamp: nil} = state) do
    {:noreply, %{state | last_timestamp: nanoseconds}}
  end

  def handle_info({:circuits_gpio, _, nanoseconds, _value}, state) do
    dt = nanoseconds - state.last_timestamp

    cond do
      dt < @debounce_ns ->
        {:noreply, state}

      dt > @stale_ns ->
        # Fan was stopped; start measurement fresh from this pulse.
        {:noreply, %{state | last_timestamp: nanoseconds, rpms: []}}

      true ->
        # 2 pulses per revolution, dt in nanoseconds → 60 * 1e9 / 2 / dt
        rpm = 30_000_000_000 / dt
        rpms = Enum.take([rpm | state.rpms], @rpm_samples)
        {:noreply, %{state | last_timestamp: nanoseconds, rpms: rpms}}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  ############################################################
  #                           Helpers                        #
  ############################################################

  @spec current_rpm(%Fanspeed{}) :: float()
  defp current_rpm(%{last_timestamp: nil}), do: 0.0

  defp current_rpm(%{last_timestamp: last, rpms: rpms}) do
    if System.monotonic_time(:nanosecond) - last > @stale_ns do
      0.0
    else
      calculate_rpm(rpms)
    end
  end

  @spec calculate_rpm([float()]) :: float()
  def calculate_rpm([]), do: 0.0

  def calculate_rpm(rpms) do
    sorted = Enum.sort(rpms)
    n = length(sorted)
    mid = div(n, 2)

    if rem(n, 2) == 1 do
      Enum.at(sorted, mid)
    else
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    end
  end

  @spec apply_speed(float()) :: :ok
  def apply_speed(percent) do
    duty = percent |> max(0.0) |> min(1.0)
    Pigpiox.Pwm.hardware_pwm(@gpio_pwm_signal, @pwm_frequency_hz, trunc(1_000_000 * duty))
    :ok
  end

  @spec configure_rpm_interrupts(String.t()) :: {:ok, term()}
  def configure_rpm_interrupts(gpio_pin) do
    {:ok, gpio} = GPIO.open(gpio_pin, :input)
    :ok = GPIO.set_pull_mode(gpio, :pullup)
    :ok = GPIO.set_interrupts(gpio, :falling)
    {:ok, gpio}
  end
end
