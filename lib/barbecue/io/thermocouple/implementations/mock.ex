defmodule Barbecue.IO.Thermocouple.Mock do
  @moduledoc """
  Mock implementation of the thermocouple.
  """
  use GenServer

  alias Barbecue.IO.Thermocouple.Mock, as: Thermocouple

  defstruct temperature: 100.0

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  ############################################################
  #                           Api                            #
  ############################################################

  @spec measure() :: float()
  def measure() do
    GenServer.call(__MODULE__, :measure)
  end

  ############################################################
  #                GenServer callbacks                       #
  ############################################################

  @impl true
  def init(_args) do
    state = %Thermocouple{temperature: 100.0}
    {:ok, state}
  end

  @impl true
  def handle_call(:measure, _from, state) do
    difference = trunc((:rand.uniform_real() - 0.5) * 5)
    state = %{state | temperature: state.temperature + difference}
    {:reply, state.temperature, state}
  end
end
