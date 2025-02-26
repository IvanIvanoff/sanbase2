defmodule Sanbase.Clickhouse.ApiCallData do
  @moduledoc ~s"""
  Get data about the API Calls that were made by users
  """
  require Sanbase.ClickhouseRepo, as: ClickhouseRepo

  @doc ~s"""
  Get a timeseries with the total number of api calls made by a user in a given interval
  """
  @spec api_call_history(non_neg_integer(), DateTime.t(), DateTime.t(), String.t()) ::
          {:ok, list(%{datetime: DateTime.t(), api_calls_count: non_neg_integer()})}
          | {:error, String.t()}
  def api_call_history(user_id, from, to, interval) do
    {query, args} = api_call_history_query(user_id, from, to, interval)

    ClickhouseRepo.query_transform(query, args, fn [t, count] ->
      %{
        datetime: DateTime.from_unix!(t),
        api_calls_count: count
      }
    end)
  end

  def active_users_count(from, to) do
    {query, args} = active_users_count_query(from, to)

    ClickhouseRepo.query_transform(query, args, fn value -> value end)
    |> case do
      {:ok, [result]} -> result
      {:error, error} -> error
    end
  end

  defp api_call_history_query(user_id, from, to, interval) do
    interval_sec = Sanbase.DateTimeUtils.str_to_sec(interval)

    query = """
    SELECT
      toUnixTimestamp(intDiv(toUInt32(dt), ?1) * ?1) AS t,
      toUInt32(count())
    FROM
      sanbase_api_call_data
    PREWHERE
      dt >= toDateTime(?2) AND
      dt < toDateTime(?3) AND
      user_id = ?4
    GROUP BY t
    ORDER BY t
    """

    args = [
      interval_sec,
      from,
      to,
      user_id
    ]

    {query, args}
  end

  defp active_users_count_query(from, to) do
    query = """
    SELECT
      uniqExact(user_id)
    FROM
      sanbase_api_call_data
    PREWHERE
      dt >= toDateTime(?1) AND
      dt < toDateTime(?2)
    """

    args = [
      from,
      to
    ]

    {query, args}
  end
end
