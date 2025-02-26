defmodule SanbaseWeb.Graphql.Clickhouse.ShareOfDepositsTest do
  use SanbaseWeb.ConnCase

  import SanbaseWeb.Graphql.TestHelpers
  import Mock
  import Sanbase.DateTimeUtils, only: [from_iso8601!: 1]
  import ExUnit.CaptureLog
  import Sanbase.Factory

  @moduletag capture_log: true

  alias Sanbase.Clickhouse.{
    ShareOfDeposits,
    EthShareOfDeposits,
    Erc20ShareOfDeposits
  }

  setup do
    %{user: user} = insert(:subscription_pro_sanbase, user: insert(:user))
    conn = setup_jwt_auth(build_conn(), user)

    token = insert(:project, %{main_contract_address: "0x123"})

    ethereum =
      insert(:project, %{
        slug: "ethereum",
        ticker: "ETH",
        main_contract_address: "0x789"
      })

    [
      conn: conn,
      token: token,
      ethereum: ethereum,
      from: from_iso8601!("2019-01-01T00:00:00Z"),
      to: from_iso8601!("2019-01-03T00:00:00Z"),
      interval: "1d"
    ]
  end

  test "logs warning when calculation errors", context do
    error = "Some error description here"

    with_mock ShareOfDeposits,
      share_of_deposits: fn _, _, _, _ -> {:error, error} end do
      assert capture_log(fn ->
               response = execute_query(context, context.token.slug)
               result = parse_response(response)
               assert result == nil
             end) =~
               graphql_error_msg("Share of Deposits", context.token.slug, error)
    end
  end

  test "returns error to the user when calculation errors", context do
    error = "Some error description here"

    with_mock ShareOfDeposits,
              [:passthrough],
              share_of_deposits: fn _, _, _, _ ->
                {:error, error}
              end do
      response = execute_query(context, context.token.slug)
      [first_error | _] = json_response(response, 200)["errors"]

      assert first_error["message"] =~
               graphql_error_msg("Share of Deposits", context.token.slug, error)
    end
  end

  test "uses 1d as default interval", context do
    with_mock ShareOfDeposits, share_of_deposits: fn _, _, _, _ -> {:ok, []} end do
      query = """
        {
          shareOfDeposits(
            slug: "#{context.token.slug}",
            from: "#{context.from}",
            to: "#{context.to}")
          {
            datetime
            activeAddresses
            activeDeposits
            shareOfDeposits
          }
        }
      """

      context.conn
      |> post("/graphql", query_skeleton(query, "shareOfDeposits"))

      assert_called(
        ShareOfDeposits.share_of_deposits(
          context.token.main_contract_address,
          context.from,
          context.to,
          "1d"
        )
      )
    end
  end

  test "works with empty interval for ERC20 tokens", context do
    with_mocks([
      {ShareOfDeposits, [:passthrough], share_of_deposits: fn _, _, _, _ -> {:ok, []} end},
      {Erc20ShareOfDeposits, [:passthrough],
       first_datetime: fn _ -> {:ok, from_iso8601!("2019-01-01T00:00:00Z")} end}
    ]) do
      query = share_of_deposits_query(context.token.slug, context.from, context.to, "")

      context.conn
      |> post("/graphql", query_skeleton(query, "shareOfDeposits"))

      assert_called(
        ShareOfDeposits.share_of_deposits(
          context.token.main_contract_address,
          context.from,
          context.to,
          "3600s"
        )
      )
    end
  end

  test "works with empty interval for ethereum", context do
    with_mocks([
      {ShareOfDeposits, [:passthrough], share_of_deposits: fn _, _, _, _ -> {:ok, []} end},
      {EthShareOfDeposits, [:passthrough],
       first_datetime: fn _ -> {:ok, from_iso8601!("2019-01-01T00:00:00Z")} end}
    ]) do
      query = share_of_deposits_query(context.ethereum.slug, context.from, context.to, "")

      context.conn
      |> post("/graphql", query_skeleton(query, "shareOfDeposits"))

      assert_called(
        ShareOfDeposits.share_of_deposits(
          context.ethereum.ticker,
          context.from,
          context.to,
          "3600s"
        )
      )
    end
  end

  test "returns share of deposits from daily active addresses for tokens", context do
    with_mock ShareOfDeposits,
      share_of_deposits: fn _, _, _, _ ->
        {:ok,
         [
           %{
             active_addresses: 100,
             active_deposits: 10,
             share_of_deposits: 10.0,
             datetime: from_iso8601!("2019-01-01T00:00:00Z")
           },
           %{
             active_addresses: 200,
             active_deposits: 10,
             share_of_deposits: 5.0,
             datetime: from_iso8601!("2019-01-02T00:00:00Z")
           }
         ]}
      end do
      response = execute_query(context, context.token.slug)
      results = parse_response(response)

      assert_called(
        ShareOfDeposits.share_of_deposits(
          context.token.main_contract_address,
          context.from,
          context.to,
          context.interval
        )
      )

      assert results == [
               %{
                 "activeAddresses" => 100,
                 "activeDeposits" => 10,
                 "shareOfDeposits" => 10.0,
                 "datetime" => "2019-01-01T00:00:00Z"
               },
               %{
                 "activeAddresses" => 200,
                 "activeDeposits" => 10,
                 "shareOfDeposits" => 5.0,
                 "datetime" => "2019-01-02T00:00:00Z"
               }
             ]
    end
  end

  test "returns share of deposits from daily active addresses for ethereum", context do
    with_mock ShareOfDeposits,
      share_of_deposits: fn _, _, _, _ ->
        {:ok,
         [
           %{
             active_addresses: 100,
             active_deposits: 10,
             share_of_deposits: 10.0,
             datetime: from_iso8601!("2019-01-01T00:00:00Z")
           },
           %{
             active_addresses: 200,
             active_deposits: 10,
             share_of_deposits: 5.0,
             datetime: from_iso8601!("2019-01-02T00:00:00Z")
           }
         ]}
      end do
      response =
        execute_query(
          context,
          context.ethereum.slug
        )

      results = parse_response(response)

      assert_called(
        ShareOfDeposits.share_of_deposits(
          context.ethereum.ticker,
          context.from,
          context.to,
          context.interval
        )
      )

      assert results == [
               %{
                 "activeAddresses" => 100,
                 "activeDeposits" => 10,
                 "shareOfDeposits" => 10.0,
                 "datetime" => "2019-01-01T00:00:00Z"
               },
               %{
                 "activeAddresses" => 200,
                 "activeDeposits" => 10,
                 "shareOfDeposits" => 5.0,
                 "datetime" => "2019-01-02T00:00:00Z"
               }
             ]
    end
  end

  defp parse_response(response) do
    json_response(response, 200)["data"]["shareOfDeposits"]
  end

  defp execute_query(context, slug) do
    query = share_of_deposits_query(slug, context.from, context.to, context.interval)

    context.conn
    |> post("/graphql", query_skeleton(query, "shareOfDeposits"))
  end

  defp share_of_deposits_query(slug, from, to, interval) do
    """
    {
      shareOfDeposits(
        slug: "#{slug}",
        from: "#{from}",
        to: "#{to}",
        interval: "#{interval}"
      )
      {
        activeAddresses
        activeDeposits
        datetime
        shareOfDeposits
      }
    }
    """
  end
end
