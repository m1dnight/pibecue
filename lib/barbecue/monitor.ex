defmodule Barbecue.Monitor do
  @moduledoc """
  Process that takes periodic measurements of the system and emits them to the
  pubsub system.
  """
  use GenServer
  require Logger

  alias Barbecue.Monitor
  alias Phoenix.PubSub

  defstruct rate: 1_000, enabled: true, timer: nil

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  ############################################################
  #                           Api                            #
  ############################################################

  def start do
    GenServer.call(__MODULE__, :start)
  end

  def stop do
    GenServer.call(__MODULE__, :stop)
  end

  ############################################################
  #                GenServer callbacks                       #
  ############################################################

  @impl true
  def init(args \\ []) do
    rate = Keyword.get(args, :rate, 1_000)

    # schedule the next measurement
    ref = schedule_measurement(rate)

    # create initial state
    state = %Monitor{rate: rate, timer: ref}
    {:ok, state}
  end

  @impl true
  def handle_call(:stop, _from, state) do
    state =
      if state.timer do
        Process.cancel_timer(state.timer)
        %{state | timer: nil}
      else
        state
      end

    {:reply, :ok, state}
  end

  def handle_call(:start, _from, state) do
    ref = schedule_measurement(state.rate)
    state = %{state | timer: ref}
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:measure, state) do
    Logger.debug("measuring system")

    take_measurements()

    ref = schedule_measurement(state.rate)

    state = %{state | timer: ref}
    {:noreply, state}
  end

  ############################################################
  #                           Helpers                        #
  ############################################################

  @spec take_measurements :: :ok
  defp take_measurements do
    fan_speed = Barbecue.IO.Fanspeed.speed()
    temperature = Barbecue.IO.Thermocouple.measure()
    target_temperature = Barbecue.Controller.target_temperature()

    system_state = %{
      fan_speed: fan_speed,
      temperature: temperature,
      target_temperature: target_temperature
    }

    # store the measurements
    {:ok, system_state} = Barbecue.Storage.States.create_state(system_state)

    Logger.debug("system: #{inspect(system_state)}")

    PubSub.broadcast(Barbecue.PubSub, "system_state", {:system_state, system_state})

    :ok
  end

  @spec schedule_measurement(non_neg_integer()) :: reference()
  defp schedule_measurement(rate) do
    Process.send_after(self(), :measure, rate)
  end
end
