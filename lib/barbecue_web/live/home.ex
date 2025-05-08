defmodule BarbecueWeb.Home do
  use BarbecueWeb, :live_view

  alias Contex.LinePlot
  alias Contex.Dataset
  alias Contex.Plot
  alias Phoenix.PubSub
  alias Barbecue.Storage.State
  alias Barbecue.Controller

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe(Barbecue.PubSub, "system_state")
    PubSub.subscribe(Barbecue.PubSub, "pid")

    socket =
      socket
      |> assign(:system_state, %State{temperature: 0.0, fan_speed: 0.0, target_temperature: 0.0})
      |> assign(:fan_speed, 0.0)
      |> assign(:pid_on?, Controller.on?())
      |> assign_async([:session_data, :session_start], fn ->
        session_data = Barbecue.Storage.States.last_session()
        session_start = Enum.min_by(session_data, & &1.time, fn -> %{time: DateTime.utc_now()} end)
        {:ok, %{session_data: session_data, session_start: session_start.time}}
      end)

    {:ok, socket}
  end

  @impl true
  def handle_info({:pid, fan_speed}, socket) do
    {:noreply, assign(socket, :fan_speed, fan_speed)}
  end

  def handle_info({:system_state, system_state}, socket) do
    session_data_async = socket.assigns.session_data

    socket =
      if session_data_async.ok? do
        session_data = session_data_async.result
        # overwrite the data in the bucket with the latest measurements
        minute = Timex.set(system_state.inserted_at, second: 0, microsecond: 0)

        session_data =
          Enum.map(session_data, fn data ->
            if data.time == minute do
              %{
                data
                | fan_speed: system_state.fan_speed,
                  target_temperature: system_state.target_temperature,
                  temperature: system_state.temperature
              }
            else
              data
            end
          end)

        socket
        |> assign(:system_state, system_state)
        |> assign(:session_data, %{session_data_async | result: session_data})
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event(_, %{"temperature" => temperature}, socket) do
    case Integer.parse(temperature) do
      {temperature, ""} ->
        Controller.set_target_temperature(temperature * 1.0)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle-control", %{"pid-control" => on?}, socket) do
    toggle = String.to_existing_atom(on?)

    if toggle do
      Controller.start()
    else
      Controller.stop()
    end

    {:noreply, assign(socket, :pid_on?, toggle)}
  end

  ############################################################
  #                           Helpers                        #
  ############################################################

  defp build_pointplot([], _, _), do: ""

  defp build_pointplot(session_data, keys, label) do
    # prepare the data for contex
    # it expects a list of maps with string keys
    # and it must be ordered
    session_data =
      session_data
      |> Enum.sort_by(& &1.time, {:asc, Date})
      |> Enum.map(fn d ->
        %{
          "time" => d.time,
          "temperature" => d.temperature,
          "fan_speed" => d.fan_speed,
          "target_temperature" => d.target_temperature
        }
      end)

    options = [
      custom_x_formatter: fn x -> Timex.format!(x, "{h24}:{m}") end,
      colour_palette: ["32CD32", "8B0000"],
      mapping: %{x_col: "time", y_cols: keys},
      legend_setting: :legend_bottom
    ]

    dataset = Dataset.new(session_data, ["time" | keys])

    Plot.new(dataset, LinePlot, 1000, 300, options)
    |> Plot.axis_labels("Time", label)
    |> Plot.to_svg()
  end
end
