defmodule Barbecue.IO.Thermocouple.Real do
  @moduledoc """
  Real implementation of the thermocouple.
  """
  use GenServer

  alias Barbecue.IO.Thermocouple.Real, as: Thermocouple
  alias Barbecue.IO.MAX31856
  defstruct ref: nil

  def start_link(args \\ []) do
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
    {:ok, ref} = MAX31856.init()
    state = %Thermocouple{ref: ref}
    {:ok, state}
  end

  @impl true
  def handle_call(:measure, _from, state) do
    temperature = MAX31856.measure(state.ref)
    {:reply, temperature, state}
  end
end
