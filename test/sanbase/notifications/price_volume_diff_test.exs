defmodule Sanbase.Notifications.PriceVolumeDiffTest do
  use Sanbase.DataCase, async: false
  use Mockery

  alias Sanbase.Notifications.PriceVolumeDiff
  alias Sanbase.Model.Project
  alias Sanbase.Prices.Store
  alias Sanbase.Influxdb.Measurement

  import Sanbase.InfluxdbHelpers

  @moduletag capture_log: true

  setup do
    setup_prices_influxdb()

    # TODO: Make projects with cmc_id and import correctly!!!

    ticker1 = "TEST"
    slug1 = "test"

    project1 =
      %Project{}
      |> Project.changeset(%{name: "Test project", slug: slug1, ticker: ticker1})
      |> Sanbase.Repo.insert!()

    ticker2 = "TESTNOVOLUME"
    slug2 = "novol"

    project2 =
      %Project{}
      |> Project.changeset(%{
        name: "Test no volume project",
        slug: slug2,
        ticker: ticker2
      })
      |> Sanbase.Repo.insert!()

    ticker_cmc_id1 = ticker1 <> "_" <> slug1

    datetime =
      DateTime.utc_now()
      |> DateTime.to_unix(:nanosecond)

    Store.import([
      %Measurement{
        timestamp: datetime,
        fields: %{volume_usd: notification_volume_threshold()},
        name: ticker_cmc_id1
      }
    ])

    [
      project1: project1,
      project2: project2
    ]
  end

  test "price & volume not diverging", context do
    mock(
      HTTPoison,
      :get,
      {:ok,
       %HTTPoison.Response{
         body:
           "[{\"price_volume_diff\": 0.001, \"price_change\": 0.04, \"volume_change\": 0.03, \"timestamp\": 1516752000}]",
         status_code: 200
       }}
    )

    mock(
      HTTPoison,
      :post,
      {:ok, %HTTPoison.Response{status_code: 204}}
    )

    PriceVolumeDiff.exec(context.project1, "USD")

    refute_called(HTTPoison, :post)
  end

  test "price & volume diverging", context do
    mock(
      HTTPoison,
      :get,
      {:ok,
       %HTTPoison.Response{
         body: """
          [
            #{Sanbase.TechIndicatorsTestResponse.price_volume_diff_prepend_response()},
            {"price_volume_diff": 123.456, "price_change": 0.04862261825993345, "volume_change": -0.030695260272520467, "timestamp": #{
           DateTime.utc_now() |> DateTime.to_unix()
         }}
          ]
         """,
         status_code: 200
       }}
    )

    mock(
      HTTPoison,
      :post,
      {:ok, %HTTPoison.Response{status_code: 204}}
    )

    PriceVolumeDiff.exec(context.project1, "USD")

    assert_called(HTTPoison, post: 3)
  end

  test "volume threshold not met", context do
    mock(
      HTTPoison,
      :get,
      {:ok,
       %HTTPoison.Response{
         body:
           "[{\"price_volume_diff\": 123.456, \"price_change\": 0.04862261825993345, \"volume_change\": -0.030695260272520467, \"timestamp\": 1516752000}]",
         status_code: 200
       }}
    )

    mock(
      HTTPoison,
      :post,
      {:ok, %HTTPoison.Response{status_code: 204}}
    )

    PriceVolumeDiff.exec(context.project2, "USD")

    refute_called(HTTPoison, :post)
  end

  defp notification_volume_threshold() do
    require Sanbase.Utils.Config, as: Config

    {res, _} =
      Config.module_get(Sanbase.Notifications.PriceVolumeDiff, :notification_volume_threshold)
      |> Integer.parse()

    res
  end
end
