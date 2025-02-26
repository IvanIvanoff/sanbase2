defmodule Sanbase.Clickhouse.V2ClickhouseMetadataTest do
  use Sanbase.DataCase, async: true

  import Sanbase.Factory

  alias Sanbase.Clickhouse.Metric

  test "can fetch metadata for all available metrics" do
    {:ok, metrics} = Metric.available_metrics()
    results = for metric <- metrics, do: Metric.metadata(metric)
    assert Enum.all?(results, &match?({:ok, _}, &1))
  end

  test "cannot fetch metadata for not available metrics" do
    {:ok, metrics} = Metric.available_metrics()
    rand_metrics = Enum.map(1..100, fn _ -> rand_str() end)
    rand_metrics = rand_metrics -- metrics

    results = for metric <- rand_metrics, do: Metric.metadata(metric)

    assert Enum.all?(results, &match?({:error, _}, &1))
  end

  test "metadata properties" do
    {:ok, metrics} = Metric.available_metrics()
    {:ok, aggregations} = Metric.available_aggregations()

    for metric <- metrics do
      {:ok, metadata} = Metric.metadata(metric)
      assert metadata.default_aggregation in aggregations
      assert metadata.min_interval in ["1d", "5m"]
    end
  end
end
