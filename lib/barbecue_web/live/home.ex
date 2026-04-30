defmodule BarbecueWeb.Home do
  @moduledoc """
  Live dashboard for the barbecue controller.

  Subscribes to `system_state` and `pid` PubSub topics, maintains a sliding
  30-minute window of bucketed measurements, and exposes events for setting
  the target temperature and toggling PID control.
  """

  use BarbecueWeb, :live_view

  alias Barbecue.Controller
  alias Barbecue.Storage.{State, States}
  alias BarbecueWeb.Live.{Chart, Temperature, Trend}
  alias Phoenix.PubSub

  # Sliding window of historical data shown on the charts (seconds).
  @window_seconds 1800

  # Aggregation bucket size for the chart data (seconds).
  @bucket_seconds 10

  # Allowed range when bumping the target temperature with the +/- buttons.
  @target_min 0
  @target_max 300

  ############################################################
  #                    LiveView callbacks                    #
  ############################################################

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe(Barbecue.PubSub, "system_state")
    PubSub.subscribe(Barbecue.PubSub, "pid")
    {:ok, initial_assigns(socket)}
  end

  @impl true
  def handle_info({:pid, fan_speed}, socket) do
    {:noreply, assign(socket, :fan_speed, fan_speed)}
  end

  def handle_info({:system_state, system_state}, socket) do
    socket =
      socket
      |> update_session_data(system_state)
      |> update_trend(system_state)
      |> assign(:system_state, system_state)

    {:noreply, socket}
  end

  ############################################################
  #                          Events                          #
  ############################################################

  @impl true
  def handle_event("target-bump", %{"by" => by}, socket) do
    delta = String.to_integer(by)
    current = trunc(socket.assigns.system_state.target_temperature)
    new_target = clamp(current + delta, @target_min, @target_max)
    Controller.set_target_temperature(new_target * 1.0)
    {:noreply, socket}
  end

  def handle_event("dial-changed", %{"value" => value}, socket) when is_integer(value) do
    Controller.set_target_temperature(value * 1.0)
    {:noreply, socket}
  end

  def handle_event("open-dial", _params, socket) do
    {:noreply, assign(socket, :dial_open?, true)}
  end

  def handle_event("close-dial", _params, socket) do
    {:noreply, assign(socket, :dial_open?, false)}
  end

  def handle_event("toggle-control", %{"pid-control" => on?}, socket) do
    on? = String.to_existing_atom(on?)
    if on?, do: Controller.start(), else: Controller.stop()
    {:noreply, assign(socket, :pid_on?, on?)}
  end

  ############################################################
  #                          Helpers                         #
  ############################################################

  # Sets initial assigns for a fresh mount.
  @spec initial_assigns(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp initial_assigns(socket) do
    socket
    |> assign(:system_state, %State{temperature: 0.0, fan_speed: 0.0, target_temperature: 0.0})
    |> assign(:previous_temperature, nil)
    |> assign(:trend, :flat)
    |> assign(:fan_speed, 0.0)
    |> assign(:dial_open?, false)
    |> assign(:pid_on?, Controller.on?())
    |> assign_async([:session_data, :session_start], &load_session/0)
  end

  # Loads the most recent measurements for the async session_data assigns.
  @spec load_session() :: {:ok, %{session_data: [map()], session_start: DateTime.t()}}
  defp load_session do
    session_data = States.recent(@window_seconds, @bucket_seconds)

    session_start =
      case session_data do
        [] -> DateTime.utc_now()
        [first | _] -> first.time
      end

    {:ok, %{session_data: session_data, session_start: session_start}}
  end

  # Updates session_data with a new measurement and prunes anything older than the window.
  @spec update_session_data(Phoenix.LiveView.Socket.t(), State.t()) ::
          Phoenix.LiveView.Socket.t()
  defp update_session_data(socket, system_state) do
    case socket.assigns.session_data do
      %{ok?: true} = async ->
        bucket = States.bucket_time(system_state.inserted_at, @bucket_seconds)
        cutoff = DateTime.add(DateTime.utc_now(), -@window_seconds, :second)

        result =
          async.result
          |> upsert_bucket(bucket, system_state)
          |> Enum.filter(&(DateTime.compare(&1.time, cutoff) != :lt))

        assign(socket, :session_data, %{async | result: result})

      _not_loaded ->
        socket
    end
  end

  # Recomputes the trend assign from the new temperature against the previous one.
  @spec update_trend(Phoenix.LiveView.Socket.t(), State.t()) :: Phoenix.LiveView.Socket.t()
  defp update_trend(socket, system_state) do
    socket
    |> assign(:trend, Trend.compute(socket.assigns.previous_temperature, system_state.temperature))
    |> assign(:previous_temperature, system_state.temperature)
  end

  # Inserts or replaces the bucket for `time` with values from `system_state`.
  @spec upsert_bucket([map()], DateTime.t(), State.t()) :: [map()]
  defp upsert_bucket(buckets, time, system_state) do
    case Enum.find_index(buckets, &(&1.time == time)) do
      nil -> buckets ++ [bucket_from_state(time, system_state)]
      idx -> List.replace_at(buckets, idx, bucket_from_state(time, system_state))
    end
  end

  # Builds a bucket map from a system state and a bucket time.
  @spec bucket_from_state(DateTime.t(), State.t()) :: map()
  defp bucket_from_state(time, system_state) do
    %{
      time: time,
      fan_speed: system_state.fan_speed,
      temperature: system_state.temperature,
      target_temperature: system_state.target_temperature
    }
  end

  # Clamps `value` between `low` and `high` (inclusive).
  @spec clamp(integer(), integer(), integer()) :: integer()
  defp clamp(value, low, high), do: max(low, min(high, value))
end
