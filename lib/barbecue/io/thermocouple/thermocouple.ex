defmodule Barbecue.IO.Thermocouple do
  @moduledoc """
  Dispatch module to dispatch calls for the thermocouple to the proper genserver.
  Can be the mocked or real server.
  """
  @spec measure :: {:ok, float()}
  def measure do
    implementation().measure()
  end

  # gets the module to use to read temperature
  @spec implementation :: atom()
  defp implementation() do
    Application.get_env(:barbecue, :thermocouple)
  end
end
