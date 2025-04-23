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

    {:ok, session_data} = Repo.transaction(fn ->
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
