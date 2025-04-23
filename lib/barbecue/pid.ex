defmodule Barbecue.PID do
  alias Barbecue.PID

  use TypedStruct

  # parameters for aggressive control
  @aggressive %{
    kp: 2.0,
    ki: 0.005,
    kd: 5.0
  }

  # parameters for slower control
  @slow %{
    kp: 1.0,
    ki: 0.01,
    kd: 0.1
  }

  # struct to hold the pid state
  typedstruct do
    field(:kp, number(), default: 2.0)
    field(:ki, number(), default: 0.005)
    field(:kd, number(), default: 5.0)
    field(:integral, number(), default: 0.0)
    field(:previous_error, number(), default: 0.0)
  end

  @doc """
  Update the pid parameters for slow or aggressive changes.
  """
  @spec set_mode(PID.t(), :slow | :aggressive) :: PID.t()
  def set_mode(state, mode) do
    case mode do
      :aggressive ->
        Map.merge(state, @aggressive)

      :slow ->
        Map.merge(state, @slow)

      _ ->
        state
    end
  end

  @doc """
  Given system parameters, compute the target control values.
  """
  @spec update(PID.t(), float(), float()) :: {PID.t(), float()}
  def update(state, temperature, target_temperature) do
    %{
      kp: kp,
      ki: ki,
      kd: kd,
      integral: integral,
      previous_error: previous_error
    } = state

    error = target_temperature - temperature

    if temperature > target_temperature do
      new_state = %{state | previous_error: error, integral: 0.0}
      {new_state, 0.0}
    else
      error = target_temperature - temperature

      integral = integral + error

      derivative = error - previous_error

      fan_speed = kp * error * ki * integral + kd * derivative
      fan_speed = max(0, min(fan_speed, 100.0))

      new_speed = fan_speed / 100
      new_state = %{state | previous_error: error, integral: integral}
      {new_state, new_speed}
    end
  end
end
