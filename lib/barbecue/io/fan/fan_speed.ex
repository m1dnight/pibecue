defmodule Barbecue.IO.Fanspeed do
  @moduledoc """
  Dispatch module to dispatch calls for the fan speed to the proper genserver.
  Can be the mocked or real server.
  """

  @spec speed :: integer()
  def speed do
    implementation().speed()
  end

  @spec set_speed(float()) :: :ok
  def set_speed(speed) do
    implementation().set_speed(speed)
  end

  # gets the module to use to read temperature
  @spec implementation :: atom()
  defp implementation() do
    Application.get_env(:barbecue, :fan_speed)
  end
end
