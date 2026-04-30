defmodule Barbecue.Storage.States do
  @moduledoc """
  Functionality to read/write system states to persistent storage.
  """

  import Ecto.Query, warn: false
  alias Barbecue.Repo
  alias Barbecue.Storage.{Sessions, State}

  @typedoc """
  An aggregated measurement for a single time bucket.
  """
  @type bucket :: %{
          time: DateTime.t(),
          fan_speed: float(),
          temperature: float(),
          target_temperature: float()
        }

  @doc """
  List all system states.
  """
  @spec states :: [State.t()]
  def states() do
    Repo.all(State)
  end

  @doc """
  Insert a new system state.

  If `:session_id` is not provided in `attrs`, the current session's id is
  used (creating a session first if the table is empty). Callers like
  `Barbecue.Monitor` therefore don't need to know about sessions.
  """
  @spec create_state(map()) :: {:ok, State.t()} | {:error, Ecto.Changeset.t()}
  def create_state(attrs) do
    attrs = Map.put_new(attrs, :session_id, Sessions.ensure_current().id)

    %State{}
    |> State.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns measurements from the last `window_seconds`, bucketed into
  `bucket_seconds`-wide buckets and averaged within each bucket.
  """
  @spec recent(pos_integer(), pos_integer()) :: [bucket()]
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

  @doc """
  Returns all measurements belonging to the current (latest) session,
  bucketed by minute and averaged within each bucket.

  Returns an empty list when there is no current session or it has no
  measurements yet.
  """
  @spec last_session() :: [bucket()]
  def last_session do
    case Sessions.current() do
      nil ->
        []

      session ->
        from(s in State,
          where: s.session_id == ^session.id,
          select: %{
            inserted_at: s.inserted_at,
            fan_speed: s.fan_speed,
            temperature: s.temperature,
            target_temperature: s.target_temperature
          }
        )
        |> Repo.all()
        |> Enum.group_by(&minute_bucket(&1.inserted_at))
        |> Enum.map(&aggregate_bucket/1)
        |> Enum.sort_by(& &1.time, {:asc, DateTime})
    end
  end

  ############################################################
  #                          Helpers                         #
  ############################################################

  # Averages the per-field values of all measurements falling into one bucket.
  @spec aggregate_bucket({DateTime.t(), [map()]}) :: bucket()
  defp aggregate_bucket({bucket, items}) do
    count = length(items)

    %{
      time: bucket,
      fan_speed: Enum.sum_by(items, & &1.fan_speed) / count,
      temperature: Enum.sum_by(items, & &1.temperature) / count,
      target_temperature: Enum.sum_by(items, & &1.target_temperature) / count
    }
  end

  # Truncates a timestamp to the start of its containing minute.
  @spec minute_bucket(DateTime.t()) :: DateTime.t()
  defp minute_bucket(dt), do: Timex.set(dt, second: 0, microsecond: 0)
end
