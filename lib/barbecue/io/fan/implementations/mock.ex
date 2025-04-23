defmodule Barbecue.IO.Fanspeed.Mock do
  use GenServer
  require Logger
  alias Barbecue.IO.Fanspeed.Mock, as: Fanspeed

  defstruct speed: 8000, set_speed: 1.0

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
    state = %Fanspeed{}
    {:ok, state}
  end

  @impl true
  def handle_call(:speed, _from, state) do
    difference = trunc((:rand.uniform_real() - 0.5) * 10)
    speed = max((state.speed * state.set_speed) + difference, 0)
    {:reply, speed, state}
  end

  def handle_call({:speed, percent}, _from, state) do
    state = %{state | set_speed: percent}
    {:reply, :ok, state}
  end
end
