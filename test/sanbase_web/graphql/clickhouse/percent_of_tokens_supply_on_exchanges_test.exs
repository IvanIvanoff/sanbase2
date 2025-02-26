defmodule SanbaseWeb.Graphql.Clickhouse.PercentOfTokenSupplyOnExchangesTest do
  use SanbaseWeb.ConnCase, async: false

  import SanbaseWeb.Graphql.TestHelpers
  import Mock
  import Sanbase.DateTimeUtils, only: [from_iso8601!: 1]
  import ExUnit.CaptureLog
  import Sanbase.Factory

  @moduletag capture_log: true

  alias Sanbase.Clickhouse.PercentOfTokenSupplyOnExchanges

  setup do
    project = insert(:project)

    [
      slug: project.slug,
      from: from_iso8601!("2019-01-01T00:00:00Z"),
      to: from_iso8601!("2019-01-03T00:00:00Z"),
      interval: "1d"
    ]
  end

  test "returns data from calculation", context do
    with_mock PercentOfTokenSupplyOnExchanges,
      percent_on_exchanges: fn _, _, _, _ ->
        {:ok,
         [
           %{
             percent_on_exchanges: 11.1,
             datetime: from_iso8601!("2019-01-01T00:00:00Z")
           },
           %{
             percent_on_exchanges: 22.2,
             datetime: from_iso8601!("2019-01-02T00:00:00Z")
           }
         ]}
      end do
      response = execute_query(context)
      values = parse_response(response)

      assert_called(
        PercentOfTokenSupplyOnExchanges.percent_on_exchanges(
          context.slug,
          context.from,
          context.to,
          context.interval
        )
      )

      assert values == [
               %{
                 "percentOnExchanges" => 11.1,
                 "datetime" => "2019-01-01T00:00:00Z"
               },
               %{
                 "percentOnExchanges" => 22.2,
                 "datetime" => "2019-01-02T00:00:00Z"
               }
             ]
    end
  end

  test "returns empty array when there is no data", context do
    with_mock PercentOfTokenSupplyOnExchanges,
      percent_on_exchanges: fn _, _, _, _ -> {:ok, []} end do
      response = execute_query(context)
      values = parse_response(response)

      assert_called(
        PercentOfTokenSupplyOnExchanges.percent_on_exchanges(
          context.slug,
          context.from,
          context.to,
          context.interval
        )
      )

      assert values == []
    end
  end

  test "logs warning when calculation errors", context do
    error = "Some error description here"

    with_mock PercentOfTokenSupplyOnExchanges,
      percent_on_exchanges: fn _, _, _, _ -> {:error, error} end do
      assert capture_log(fn ->
               response = execute_query(context)
               values = parse_response(response)
               assert values == nil
             end) =~
               graphql_error_msg("Percent of Token Supply on Exchanges", context.slug, error)
    end
  end

  test "returns error to the user when calculation errors", context do
    error = "Some error description here"

    with_mock PercentOfTokenSupplyOnExchanges,
              [:passthrough],
              percent_on_exchanges: fn _, _, _, _ ->
                {:error, error}
              end do
      response = execute_query(context)
      [first_error | _] = json_response(response, 200)["errors"]

      assert first_error["message"] =~
               graphql_error_msg("Percent of Token Supply on Exchanges", context.slug, error)
    end
  end

  test "uses 1d as default interval", context do
    with_mock PercentOfTokenSupplyOnExchanges,
      percent_on_exchanges: fn _, _, _, _ -> {:ok, []} end do
      query = """
        {
          percentOfTokenSupplyOnExchanges(
            slug: "#{context.slug}",
            from: "#{context.from}",
            to: "#{context.to}")
          {
            datetime
            percentOnExchanges
          }
        }
      """

      context.conn
      |> post("/graphql", query_skeleton(query, "percentOfTokenSupplyOnExchanges"))

      assert_called(
        PercentOfTokenSupplyOnExchanges.percent_on_exchanges(
          context.slug,
          context.from,
          context.to,
          "1d"
        )
      )
    end
  end

  defp parse_response(response) do
    json_response(response, 200)["data"]["percentOfTokenSupplyOnExchanges"]
  end

  defp execute_query(context) do
    query = percent_on_exchanges_query(context.slug, context.from, context.to, context.interval)

    context.conn
    |> post("/graphql", query_skeleton(query, "realizedValue"))
  end

  defp percent_on_exchanges_query(slug, from, to, interval) do
    """
      {
        percentOfTokenSupplyOnExchanges(
          slug: "#{slug}",
          from: "#{from}",
          to: "#{to}",
          interval: "#{interval}")
        {
            datetime,
            percentOnExchanges
        }
      }
    """
  end
end
