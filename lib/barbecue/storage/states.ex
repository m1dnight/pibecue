defmodule Barbecue.Storage.States do
  @moduledoc """
  Functionality to read/write system states to persistent storage.
  """

  import Ecto.Query, warn: false
  alias Barbecue.Repo
  alias Barbecue.Storage.State

  @doc """
  List all system states.
  """
  @spec states :: [State.t()]
  def states() do
    Repo.all(State)
  end

  @doc """
  Insert new system state.
  """
  @spec create_state(map()) :: {:ok, State.t()} | {:error, Ecto.Changeset.t()}
  def create_state(attrs) do
    %State{}
    |> State.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns measurements from the last `window_seconds`, bucketed into
  `bucket_seconds`-wide buckets and averaged within each bucket.
  """
  @spec recent(pos_integer(), pos_integer()) :: [
          %{
            time: DateTime.t(),
            fan_speed: float(),
            temperature: float(),
            target_temperature: float()
          }
        ]
  def recent(window_seconds \\ 1800, bucket_seconds \\ 10) do
    cutoff = DateTime.utc_now() |> DateTime.add(-window_seconds, :second)

    query =
      from(s in State,
        where: s.inserted_at >= ^cutoff,
        select: %{
          inserted_at: s.inserted_at,
          fan_speed: s.fan_speed,
          temperature: s.temperature,
          target_temperature: s.target_temperature
        }
      )

    Repo.all(query)
    |> Enum.group_by(&bucket_time(&1.inserted_at, bucket_seconds))
    |> Enum.map(&aggregate_bucket/1)
    |> Enum.sort_by(& &1.time, {:asc, DateTime})
  end

  @doc """
  Truncates a DateTime to the start of its `bucket_seconds`-wide bucket.
  """
  @spec bucket_time(DateTime.t(), pos_integer()) :: DateTime.t()
  def bucket_time(dt, bucket_seconds) do
    unix = DateTime.to_unix(dt)
    DateTime.from_unix!(div(unix, bucket_seconds) * bucket_seconds)
  end

  defp aggregate_bucket({bucket, items}) do
    count = length(items)

    %{
      time: bucket,
      fan_speed: Enum.sum_by(items, & &1.fan_speed) / count,
      temperature: Enum.sum_by(items, & &1.temperature) / count,
      target_temperature: Enum.sum_by(items, & &1.target_temperature) / count
    }
  end

  @doc """
  Returns all the latest measurements that are close to eachother, and thus are in the same session.
  """
  @spec last_session :: [%{time: DateTime.t(), fan_speed: float(), temperature: float()}]
  def last_session() do
    # query to select states with a diff compares to their previous measurement
    query =
      from(s in State,
        select: %{
          id: s.id,
          inserted_at: s.inserted_at,
          fan_speed: s.fan_speed,
          temperature: s.temperature,
          target_temperature: s.target_temperature,
          time_diff:
            fragment(
              "JULIANDAY(?) - JULIANDAY(LAG(?) OVER (ORDER BY ?))",
              s.inserted_at,
              s.inserted_at,
              s.inserted_at
            )
        },
        order_by: {:desc, s.inserted_at}
      )

    # stream the data and take until the next measurement is too far apart
    stream = Repo.stream(query)

    {:ok, session_data} =
      Repo.transaction(fn ->
        stream
        # take the last session's measurements
        |> Stream.take_while(fn measurement ->
          measurement.time_diff == nil or measurement.time_diff * 1440 < 5
        end)
        # round to the nearest minute
        |> Stream.map(fn measurement ->
          %{
            measurement
            | inserted_at: Timex.set(measurement.inserted_at, second: 0, microsecond: 0)
          }
        end)
        |> Enum.to_list()
        # group by rounded time
        |> Enum.group_by(& &1.inserted_at)
        # calculate average
        |> Enum.map(fn {bucket, items} ->
          count = Enum.count(items)

          fan_speed = Enum.map(items, & &1.fan_speed) |> Enum.sum()
          temperature = Enum.map(items, & &1.temperature) |> Enum.sum()
          target_temperature = Enum.map(items, & &1.target_temperature) |> Enum.sum()

          %{
            time: bucket,
            fan_speed: fan_speed / count,
            temperature: temperature / count,
            target_temperature: target_temperature / count
          }
        end)
      end)

    session_data
  end
end
