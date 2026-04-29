defmodule BarbecueWeb.Home do
  use BarbecueWeb, :live_view

  alias Contex.LinePlot
  alias Contex.Dataset
  alias Contex.Plot
  alias Phoenix.PubSub
  alias Barbecue.Storage.State
  alias Barbecue.Storage.States
  alias Barbecue.Controller

  @window_seconds 1800
  @bucket_seconds 10

  @impl true
  def mount(_params, _session, socket) do
    PubSub.subscribe(Barbecue.PubSub, "system_state")
    PubSub.subscribe(Barbecue.PubSub, "pid")

    socket =
      socket
      |> assign(:system_state, %State{temperature: 0.0, fan_speed: 0.0, target_temperature: 0.0})
      |> assign(:previous_temperature, nil)
      |> assign(:trend, :flat)
      |> assign(:fan_speed, 0.0)
      |> assign(:pid_on?, Controller.on?())
      |> assign_async([:session_data, :session_start], fn ->
        session_data = States.recent(@window_seconds, @bucket_seconds)

        session_start =
          case session_data do
            [] -> DateTime.utc_now()
            [first | _] -> first.time
          end

        {:ok, %{session_data: session_data, session_start: session_start}}
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
        bucket = States.bucket_time(system_state.inserted_at, @bucket_seconds)
        cutoff = DateTime.add(DateTime.utc_now(), -@window_seconds, :second)

        session_data =
          session_data_async.result
          |> upsert_bucket(bucket, system_state)
          |> Enum.filter(&(DateTime.compare(&1.time, cutoff) != :lt))

        socket
        |> assign(:session_data, %{session_data_async | result: session_data})
      else
        socket
      end

    socket =
      socket
      |> assign(:trend, compute_trend(socket.assigns.previous_temperature, system_state.temperature))
      |> assign(:previous_temperature, system_state.temperature)
      |> assign(:system_state, system_state)

    {:noreply, socket}
  end

  defp upsert_bucket(buckets, time, system_state) do
    case Enum.find_index(buckets, &(&1.time == time)) do
      nil ->
        buckets ++
          [
            %{
              time: time,
              fan_speed: system_state.fan_speed,
              temperature: system_state.temperature,
              target_temperature: system_state.target_temperature
            }
          ]

      idx ->
        List.update_at(buckets, idx, fn bucket ->
          %{
            bucket
            | fan_speed: system_state.fan_speed,
              temperature: system_state.temperature,
              target_temperature: system_state.target_temperature
          }
        end)
    end
  end

  defp compute_trend(nil, _current), do: :flat

  defp compute_trend(previous, current) do
    cond do
      current - previous > 0.2 -> :up
      previous - current > 0.2 -> :down
      true -> :flat
    end
  end

  @impl true
  def handle_event("temperature", %{"temperature" => temperature}, socket) do
    case Integer.parse(temperature) do
      {temperature, ""} ->
        Controller.set_target_temperature(temperature * 1.0)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("target-bump", %{"by" => by}, socket) do
    delta = String.to_integer(by)
    new_target = max(0, min(300, trunc(socket.assigns.system_state.target_temperature) + delta))
    Controller.set_target_temperature(new_target * 1.0)
    {:noreply, socket}
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

  def format_delta(delta) when delta > 0, do: "+#{Float.round(delta, 1)}°C"
  def format_delta(delta), do: "#{Float.round(delta, 1)}°C"

  def trend_icon(:up), do: "hero-arrow-trending-up"
  def trend_icon(:down), do: "hero-arrow-trending-down"
  def trend_icon(:flat), do: "hero-minus"

  def trend_color(:up), do: "text-rose-500"
  def trend_color(:down), do: "text-sky-500"
  def trend_color(:flat), do: "text-slate-400"

  def zone_color(temperature, target) do
    cond do
      target == 0.0 -> "text-slate-700"
      abs(temperature - target) <= 5 -> "text-emerald-600"
      abs(temperature - target) <= 15 -> "text-amber-500"
      true -> "text-rose-600"
    end
  end

  def build_pointplot([], _, _, _), do: ""

  def build_pointplot(session_data, keys, label, palette) do
    session_data =
      session_data
      |> Enum.sort_by(& &1.time, {:asc, DateTime})
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
      colour_palette: palette,
      mapping: %{x_col: "time", y_cols: keys},
      legend_setting: :legend_none,
      smoothed: false
    ]

    dataset = Dataset.new(session_data, ["time" | keys])

    Plot.new(dataset, LinePlot, 1000, 300, options)
    |> Plot.axis_labels("", label)
    |> Plot.to_svg()
    |> responsive_svg()
  end

  defp responsive_svg({:safe, iodata}), do: responsive_svg(IO.iodata_to_binary(iodata))

  defp responsive_svg(svg) when is_binary(svg) do
    svg
    |> String.replace(
      ~r/<svg([^>]*?)>/s,
      fn match ->
        cond do
          String.contains?(match, "viewBox") ->
            match

          true ->
            w = Regex.run(~r/width="(\d+)"/, match) |> List.last() || "1000"
            h = Regex.run(~r/height="(\d+)"/, match) |> List.last() || "300"

            match
            |> String.replace(~r/width="\d+"/, ~s|width="100%"|)
            |> String.replace(~r/height="\d+"/, ~s|height="100%"|)
            |> String.replace(
              ~r/<svg/,
              ~s|<svg viewBox="0 0 #{w} #{h}" preserveAspectRatio="xMidYMid meet" style="display:block"|
            )
        end
      end
    )
    |> Phoenix.HTML.raw()
  end
end
