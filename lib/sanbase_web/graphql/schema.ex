defmodule SanbaseWeb.Graphql.Schema do
  @moduledoc ~s"""
  The definition of the GraphQL Schema.

  There are no fields explicitlty defined here. Queries, mutations and types
  are defined in modules separated by concern. Then they are imported
  via import_types/1 or import_fields/1

  When defining a query there must be defined also a meta key 'subscription'.
  These subscriptions have the following values:
    > free
    > basic
    > pro
    > premium
    > enterprise
  """
  use Absinthe.Schema
  use Absinthe.Ecto, repo: Sanbase.Repo

  alias SanbaseWeb.Graphql
  alias SanbaseWeb.Graphql.Prometheus
  alias SanbaseWeb.Graphql.{SanbaseRepo, SanbaseDataloader}
  alias SanbaseWeb.Graphql.Middlewares.ApiUsage

  import_types(Absinthe.Plug.Types)
  import_types(Graphql.TagTypes)
  import_types(Graphql.CustomTypes)
  import_types(Graphql.AccountTypes)
  import_types(Graphql.TransactionTypes)
  import_types(Graphql.FileTypes)
  import_types(Graphql.UserListTypes)
  import_types(Graphql.MarketSegmentTypes)
  import_types(Graphql.UserSettingsTypes)
  import_types(Graphql.UserTriggerTypes)
  import_types(Graphql.CustomTypes.JSON)
  import_types(Graphql.PaginationTypes)
  import_types(Graphql.SignalsHistoricalActivityTypes)
  import_types(Graphql.TimelineEventTypes)
  import_types(Graphql.InsightTypes)
  import_types(Graphql.TwitterTypes)
  import_types(Graphql.MetricTypes)

  import_types(Graphql.Schema.MetricQueries)
  import_types(Graphql.Schema.SocialDataQueries)
  import_types(Graphql.Schema.WatchlistQueries)
  import_types(Graphql.Schema.ProjectQueries)
  import_types(Graphql.Schema.InsightQueries)
  import_types(Graphql.Schema.TechIndicatorsQueries)
  import_types(Graphql.Schema.PriceQueries)
  import_types(Graphql.Schema.GithubQueries)
  import_types(Graphql.Schema.BlockchainQueries)
  import_types(Graphql.Schema.SignalQueries)
  import_types(Graphql.Schema.FeaturedQueries)
  import_types(Graphql.Schema.UserQueries)
  import_types(Graphql.Schema.TimelineQueries)
  import_types(Graphql.Schema.BillingQueries)

  def dataloader() do
    # 11 seconds is 1s more than the influxdb timeout
    Dataloader.new(timeout: :timer.seconds(11))
    |> Dataloader.add_source(SanbaseRepo, SanbaseRepo.data())
    |> Dataloader.add_source(SanbaseDataloader, SanbaseDataloader.data())
  end

  def context(ctx) do
    ctx
    |> Map.put(:loader, dataloader())
  end

  def plugins do
    [
      Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()
    ]
  end

  def middleware(middlewares, field, object) do
    case object.identifier do
      :query ->
        [
          ApiUsage
          | middlewares
            |> Prometheus.HistogramInstrumenter.instrument(field, object)
            |> Prometheus.CounterInstrumenter.instrument(field, object)
        ]

      _ ->
        middlewares
        |> Prometheus.HistogramInstrumenter.instrument(field, object)
        |> Prometheus.CounterInstrumenter.instrument(field, object)
    end
  end

  query do
    import_fields(:metric_queries)
    import_fields(:social_data_queries)
    import_fields(:user_list_queries)
    import_fields(:project_queries)
    import_fields(:project_eth_spent_queries)
    import_fields(:insight_queries)
    import_fields(:tech_indicators_queries)
    import_fields(:price_queries)
    import_fields(:github_queries)
    import_fields(:blockchain_queries)
    import_fields(:signal_queries)
    import_fields(:featured_queries)
    import_fields(:user_queries)
    import_fields(:timeline_queries)
    import_fields(:billing_queries)
  end

  mutation do
    import_fields(:user_list_mutations)
    import_fields(:insight_mutations)
    import_fields(:signal_mutations)
    import_fields(:user_mutations)
    import_fields(:billing_mutations)
  end
end
