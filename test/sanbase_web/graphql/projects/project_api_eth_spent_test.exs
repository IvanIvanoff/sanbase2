defmodule SanbaseWeb.Graphql.ProjecApiEthSpentTest do
  use SanbaseWeb.ConnCase, async: false

  import Mock
  import Sanbase.Factory
  import SanbaseWeb.Graphql.TestHelpers

  @eth_decimals 1_000_000_000_000_000_000

  setup do
    datetime1 = Timex.now() |> Timex.beginning_of_day()
    datetime2 = Timex.shift(datetime1, days: -10)
    datetime3 = Timex.shift(datetime1, days: -15)

    eth_infr = insert(:infrastructure, %{code: "ETH"})

    p =
      insert(:project, %{
        name: "Santiment",
        ticker: "SAN",
        slug: "santiment",
        infrastructure_id: eth_infr.id,
        main_contract_address: "0x" <> rand_hex_str()
      })

    project_address = p.eth_addresses |> List.first()

    [
      project: p,
      project_address: project_address.address,
      dates_day_diff1: Timex.diff(datetime1, datetime3, :days) + 1,
      expected_sum1: 20_000,
      dates_day_diff2: Timex.diff(datetime1, datetime2, :days) + 1,
      expected_sum2: 4500,
      datetime_from: datetime3,
      datetime_to: datetime1
    ]
  end

  test "project total eth spent whole interval", context do
    with_mock Sanbase.ClickhouseRepo, [:passthrough],
      query: fn _, _ ->
        {:ok,
         %{
           rows: [
             [
               context.project_address,
               30_000 * @eth_decimals,
               10_000 * @eth_decimals,
               -20_000 * @eth_decimals
             ]
           ]
         }}
      end do
      query = """
      {
        project(id: #{context.project.id}) {
          ethSpent(days: #{context.dates_day_diff1})
        }
      }
      """

      result =
        context.conn
        |> post("/graphql", query_skeleton(query, "project"))

      trx_sum = json_response(result, 200)["data"]["project"]

      assert trx_sum == %{"ethSpent" => context.expected_sum1}
    end
  end

  test "project total eth spent part of interval", context do
    eth_spent = 4500

    with_mock Sanbase.ClickhouseRepo, [:passthrough],
      query: fn _, _ ->
        {:ok,
         %{
           rows: [
             [
               context.project_address,
               20_000 * @eth_decimals,
               15_500 * @eth_decimals,
               -4500 * @eth_decimals
             ]
           ]
         }}
      end do
      query = """
      {
        project(id: #{context.project.id}) {
          ethSpent(days: #{context.dates_day_diff2})
        }
      }
      """

      result =
        context.conn
        |> post("/graphql", query_skeleton(query, "project"))

      trx_sum = json_response(result, 200)["data"]["project"]

      assert trx_sum == %{"ethSpent" => eth_spent}
    end
  end

  test "eth spent by erc20 projects", context do
    eth_spent = 30_000

    with_mock Sanbase.ClickhouseRepo, [:passthrough],
      query: fn _, _ ->
        {:ok,
         %{
           rows: [
             [
               context.project_address,
               100_000 * @eth_decimals,
               70_000 * @eth_decimals,
               -30_000 * @eth_decimals
             ]
           ]
         }}
      end do
      query = """
      {
        ethSpentByErc20Projects(
          from: "#{context.datetime_from}",
          to: "#{context.datetime_to}")
      }
      """

      result =
        context.conn
        |> post("/graphql", query_skeleton(query, "ethSpentByErc20Projects"))

      total_eth_spent = json_response(result, 200)["data"]["ethSpentByErc20Projects"]

      assert total_eth_spent == eth_spent
    end
  end

  test "eth spent over time by erc20 projects", context do
    dt1 = Timex.now() |> DateTime.to_unix()
    dt2 = Timex.shift(Timex.now(), days: -1) |> DateTime.to_unix()
    dt3 = Timex.shift(Timex.now(), days: -2) |> DateTime.to_unix()
    dt4 = Timex.shift(Timex.now(), days: -3) |> DateTime.to_unix()
    dt5 = Timex.shift(Timex.now(), days: -4) |> DateTime.to_unix()

    with_mock Sanbase.ClickhouseRepo, [:passthrough],
      query: fn _, _ ->
        {:ok,
         %{
           rows: [
             [dt1, -16_500 * @eth_decimals],
             [dt2, -5500 * @eth_decimals],
             [dt3, -3500 * @eth_decimals],
             [dt4, -2500 * @eth_decimals],
             [dt5, -500 * @eth_decimals]
           ]
         }}
      end do
      query = """
      {
        ethSpentOverTimeByErc20Projects(
          from: "#{context.datetime_from}",
          to: "#{context.datetime_to}",
          interval: "5d"){
            ethSpent
          }
      }
      """

      result =
        context.conn
        |> post("/graphql", query_skeleton(query, "ethSpentOverTimeByErc20Projects"))

      total_spent = json_response(result, 200)["data"]["ethSpentOverTimeByErc20Projects"]

      assert %{"ethSpent" => 16_500.0} in total_spent
      assert %{"ethSpent" => 5500.0} in total_spent
      assert %{"ethSpent" => 3500.0} in total_spent
      assert %{"ethSpent" => 2500.0} in total_spent
      assert %{"ethSpent" => 500.0} in total_spent
    end
  end

  # Private functions
end
