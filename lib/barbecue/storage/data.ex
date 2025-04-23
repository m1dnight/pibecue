# defmodule Barbecue.Storage do
#   alias Barbecue.Repo
#   alias Ecto.Adapters.SQL

#   # def temperatures do
#   #   query = """
#   #   WITH time_differences AS (SELECT *,
#   #                                   JULIANDAY(inserted_at) -
#   #                                   JULIANDAY(LAG(inserted_at) OVER (ORDER BY inserted_at)) AS time_diff
#   #                             FROM temperature),
#   #       group_boundaries AS (SELECT *,
#   #                                   SUM(CASE WHEN time_diff > 1.0 / 1440 OR time_diff IS NULL THEN 1 ELSE 0 END)
#   #                                       OVER (ORDER BY inserted_at) AS group_id
#   #                             FROM time_differences),
#   #       group_info AS (SELECT group_id, MAX(inserted_at) AS group_end, COUNT(*) AS group_size
#   #                       FROM group_boundaries
#   #                       GROUP BY group_id),
#   #       group_values AS (SELECT gb.*
#   #                         FROM group_boundaries gb
#   #                         WHERE gb.group_id = (SELECT group_id
#   #                                             FROM group_info
#   #                                             ORDER BY group_end DESC
#   #                                             LIMIT 1)
#   #                         ORDER BY gb.inserted_at)
#   #   SELECT STRFTIME('%Y-%m-%d %H:%M:00+00:00', inserted_at) AS inserted_at, AVG(value)
#   #   FROM group_values
#   #   GROUP BY STRFTIME('%Y-%m-%d %H:%M:00+00:00', inserted_at);
#   #   """

#   #   case SQL.query(Repo, query, []) do
#   #     {:ok, %{rows: rows}} ->
#   #       Enum.map(rows, fn [time, value] ->
#   #         {Timex.parse!(time, "{RFC3339}"), value}
#   #       end)

#   #     {:error, e} ->
#   #       {:error, :failed_to_get_measurements, e}
#   #   end
#   # end

#   # def speeds do
#   #   query = """
#   #   WITH time_differences AS (SELECT *,
#   #                                   JULIANDAY(inserted_at) -
#   #                                   JULIANDAY(LAG(inserted_at) OVER (ORDER BY inserted_at)) AS time_diff
#   #                             FROM fan_speed),
#   #       group_boundaries AS (SELECT *,
#   #                                   SUM(CASE WHEN time_diff > 1.0 / 1440 OR time_diff IS NULL THEN 1 ELSE 0 END)
#   #                                       OVER (ORDER BY inserted_at) AS group_id
#   #                             FROM time_differences),
#   #       group_info AS (SELECT group_id, MAX(inserted_at) AS group_end, COUNT(*) AS group_size
#   #                       FROM group_boundaries
#   #                       GROUP BY group_id),
#   #       group_values AS (SELECT gb.*
#   #                         FROM group_boundaries gb
#   #                         WHERE gb.group_id = (SELECT group_id
#   #                                             FROM group_info
#   #                                             ORDER BY group_end DESC
#   #                                             LIMIT 1)
#   #                         ORDER BY gb.inserted_at)
#   #   SELECT STRFTIME('%Y-%m-%d %H:%M:00+00:00', inserted_at) AS inserted_at, AVG(value)
#   #   FROM group_values
#   #   GROUP BY STRFTIME('%Y-%m-%d %H:%M:00+00:00', inserted_at);
#   #   """

#   #   case SQL.query(Repo, query, []) do
#   #     {:ok, %{rows: rows}} ->
#   #       Enum.map(rows, fn [time, value] ->
#   #         {Timex.parse!(time, "{RFC3339}"), value}
#   #       end)

#   #     {:error, e} ->
#   #       {:error, :failed_to_get_measurements, e}
#   #   end
#   # end
# end
