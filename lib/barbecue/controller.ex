defmodule Barbecue.Controller do
  @moduledoc """
  Process that controls the fan speed based on current system state.
  """
  use GenServer

  alias Barbecue.PID
  alias Barbecue.Controller
  alias Barbecue.IO.Fanspeed
  alias Phoenix.PubSub

  require Logger

  defstruct pid: %PID{}, target_temperature: 0.0, enabled: true

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  ############################################################
  #                           Api                            #
  ############################################################

  @doc """
  Returns the current target temperature.
  """
  @spec target_temperature :: float()
  def target_temperature() do
    GenServer.call(__MODULE__, :target_temperature)
  end

  @doc """
  Sets the current target temperature.
  """
  @spec set_target_temperature(float()) :: float()
  def set_target_temperature(target_temperature) do
    GenServer.call(__MODULE__, {:target_temperature, target_temperature})
  end

  @spec start :: :ok
  def start() do
    GenServer.call(__MODULE__, :start)
  end

  @spec stop :: :ok
  def stop() do
    GenServer.call(__MODULE__, :stop)
  end

  @spec on? :: boolean()
  def on?() do
    GenServer.call(__MODULE__, :state?)
  end

  ############################################################
  #                GenServer callbacks                       #
  ############################################################

  @impl true
  def init(_args) do
    Logger.debug("starting controller")

    # subscribe to system updates
    PubSub.subscribe(Barbecue.PubSub, "system_state")

    state = %Controller{}
    {:ok, state}
  end

  @impl true
  def handle_call(:target_temperature, _from, state) do
    {:reply, state.target_temperature, state}
  end

  def handle_call({:target_temperature, target_temperature}, _from, state) do
    {:reply, :ok, %{state | target_temperature: target_temperature}}
  end

  def handle_call(:start, _from, state) do
    {:reply, :ok, %{state | enabled: true}}
  end

  def handle_call(:stop, _from, state) do
    # set the fan speed to the new value
    set_fan_speed(0.0)

    {:reply, :ok, %{state | enabled: false}}
  end

  def handle_call(:state?, _from, state) do
    {:reply, state.enabled, state}
  end

  @impl true
  def handle_info({:system_state, _}, state = %{enabled: false}) do
    {:noreply, state}
  end

  def handle_info({:system_state, system_state}, state) do
    %{temperature: temperature} = system_state
    # run the pid calculations to determine new fan speed
    {pid, fan_speed} = PID.update(state.pid, temperature, state.target_temperature)

    # set the fan speed to the new value
    set_fan_speed(fan_speed)

    # announce the new fan speed
    PubSub.broadcast(Barbecue.PubSub, "pid", {:pid, fan_speed})

    # update the state for the next iteration
    state = %{state | pid: pid}

    # return the new fan speed
    {:noreply, state}
  end

  ############################################################
  #                           Helpers                        #
  ############################################################

  @spec set_fan_speed(float()) :: :ok
  defp set_fan_speed(fan_speed) do
    Logger.debug("setting fan speed to #{trunc(fan_speed * 100)} percent.")
    Fanspeed.set_speed(fan_speed)
  end
end
