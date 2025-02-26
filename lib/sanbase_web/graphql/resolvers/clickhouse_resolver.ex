defmodule SanbaseWeb.Graphql.Resolvers.ClickhouseResolver do
  require Logger

  alias Sanbase.Model.Project
  import SanbaseWeb.Graphql.Helpers.Utils, only: [fit_from_datetime: 2, calibrate_interval: 7]

  import Absinthe.Resolution.Helpers, only: [on_load: 2]

  alias SanbaseWeb.Graphql.SanbaseDataloader

  import Sanbase.Utils.ErrorHandling,
    only: [handle_graphql_error: 3, handle_graphql_error: 4]

  alias Sanbase.Clickhouse.HistoricalBalance.MinersBalance

  alias Sanbase.Clickhouse.{
    DailyActiveAddresses,
    DailyActiveDeposits,
    GasUsed,
    HistoricalBalance,
    MiningPoolsDistribution,
    MVRV,
    NetworkGrowth,
    NVT,
    PercentOfTokenSupplyOnExchanges,
    RealizedValue,
    TopHolders,
    ShareOfDeposits,
    TokenCirculation,
    TokenVelocity,
    Bitcoin
  }

  # Return this number of datapoints is the provided interval is an empty string
  @datapoints 50

  @one_hour_in_seconds 3_600

  def top_holders_percent_of_total_supply(
        _root,
        %{
          slug: slug,
          number_of_holders: number_of_holders,
          from: from,
          to: to,
          interval: interval
        },
        _resolution
      ) do
    with {:ok, contract, token_decimals} <- Project.contract_info_by_slug(slug),
         {:ok, percent_of_total_supply} <-
           TopHolders.percent_of_total_supply(
             contract,
             token_decimals,
             number_of_holders,
             from,
             to,
             interval
           ) do
      {:ok, percent_of_total_supply}
    else
      {:error, error} ->
        {:error, handle_graphql_error("Top Holders - percent of total supply", slug, error)}
    end
  end

  def gas_used(
        _root,
        %{slug: slug, from: from, to: to, interval: interval},
        _resolution
      ) do
    case GasUsed.gas_used(slug, from, to, interval) do
      {:ok, gas_used} ->
        {:ok, gas_used}

      {:error, error} ->
        {:error, handle_graphql_error("Gas Used", slug, error)}
    end
  end

  def network_growth(_root, %{slug: slug, from: from, to: to, interval: interval}, _resolution) do
    with {:ok, contract, _} <- Project.contract_info_by_slug(slug),
         {:ok, network_growth} <-
           NetworkGrowth.network_growth(contract, from, to, interval) do
      {:ok, network_growth}
    else
      {:error, error} ->
        {:error, handle_graphql_error("Network Growth", slug, error)}
    end
  end

  def mining_pools_distribution(
        _root,
        %{slug: slug, from: from, to: to, interval: interval},
        _resolution
      ) do
    case MiningPoolsDistribution.distribution(slug, from, to, interval) do
      {:ok, distribution} ->
        {:ok, distribution}

      {:error, error} ->
        {:error, handle_graphql_error("Mining Pools Distribution", slug, error)}
    end
  end

  def miners_balance(
        _root,
        %{slug: slug, from: from, to: to, interval: interval},
        _resolution
      ) do
    with {:ok, from, to, interval} <-
           calibrate_interval(
             MinersBalance,
             slug,
             from,
             to,
             interval,
             86400,
             @datapoints
           ),
         {:ok, balance} <-
           MinersBalance.historical_balance(slug, from, to, interval) do
      {:ok, balance}
    else
      {:error, error} ->
        {:error, handle_graphql_error("Miners Balance", slug, error)}
    end
  end

  def mvrv_ratio(_root, %{slug: "bitcoin", from: from, to: to, interval: interval}, _resolution) do
    with {:ok, from, to, interval} <-
           calibrate_interval(Bitcoin, "bitcoin", from, to, interval, 86_400, @datapoints) do
      Bitcoin.mvrv_ratio(from, to, interval)
    end
  end

  def mvrv_ratio(_root, %{slug: slug, from: from, to: to, interval: interval}, _resolution) do
    # TODO: Check if interval is a whole day as in token circulation
    with {:ok, mvrv_ratio} <- MVRV.mvrv_ratio(slug, from, to, interval) do
      {:ok, mvrv_ratio}
    else
      {:error, error} ->
        {:error, handle_graphql_error("MVRV Ratio", slug, error)}
    end
  end

  def token_circulation(
        _root,
        %{slug: slug, from: from, to: to, interval: interval} = args,
        _resolution
      ) do
    with ticker when is_binary(ticker) <- Project.ticker_by_slug(slug),
         ticker_slug <- ticker <> "_" <> slug,
         {:ok, from, to, interval} <-
           calibrate_interval(
             TokenCirculation,
             ticker_slug,
             from,
             to,
             interval,
             86_400,
             @datapoints
           ),
         {:ok, token_circulation} <-
           TokenCirculation.token_circulation(
             :less_than_a_day,
             ticker_slug,
             from,
             to,
             interval
           ) do
      {:ok, token_circulation |> fit_from_datetime(args)}
    else
      {:error, error} ->
        {:error, handle_graphql_error("Token Circulation", slug, error)}
    end
  end

  def token_velocity(
        _root,
        %{slug: slug, from: from, to: to, interval: interval} = args,
        _resolution
      ) do
    with ticker when is_binary(ticker) <- Project.ticker_by_slug(slug),
         ticker_slug <- ticker <> "_" <> slug,
         {:ok, from, to, interval} <-
           calibrate_interval(TokenVelocity, ticker_slug, from, to, interval, 86_400, @datapoints),
         {:ok, token_velocity} <-
           TokenVelocity.token_velocity(ticker_slug, from, to, interval) do
      {:ok, token_velocity |> fit_from_datetime(args)}
    else
      {:error, error} ->
        {:error, handle_graphql_error("Token Velocity", slug, error)}
    end
  end

  def daily_active_addresses(
        _root,
        %{slug: slug, from: from, to: to, interval: interval},
        _resolution
      ) do
    with {:ok, contract, _} <- Project.contract_info_by_slug(slug),
         {:ok, from, to, interval} <-
           calibrate_interval(
             DailyActiveAddresses,
             contract,
             from,
             to,
             interval,
             86_400,
             @datapoints
           ),
         {:ok, daily_active_addresses} <-
           DailyActiveAddresses.average_active_addresses(
             contract,
             from,
             to,
             interval
           ) do
      {:ok, daily_active_addresses}
    else
      {:error, {:missing_contract, error_msg}} ->
        {:error, error_msg}

      {:error, error} ->
        {:error, handle_graphql_error("Daily Active Addresses", slug, error)}
    end
  end

  @doc ~S"""
  Returns the average number of daily active addresses for the last 30 days
  """
  def average_daily_active_addresses(
        %Project{} = project,
        args,
        %{context: %{loader: loader}}
      ) do
    to = Map.get(args, :to, Timex.now())
    from = Map.get(args, :from, Timex.shift(to, days: -30))

    loader
    |> Dataloader.load(SanbaseDataloader, :average_daily_active_addresses, %{
      project: project,
      from: from,
      to: to
    })
    |> on_load(&average_daily_active_addresses_on_load(&1, project))
  end

  defp average_daily_active_addresses_on_load(loader, project) do
    with {:ok, contract_address, _token_decimals} <- Project.contract_info(project) do
      average_daily_active_addresses =
        loader
        |> Dataloader.get(
          SanbaseDataloader,
          :average_daily_active_addresses,
          contract_address
        ) || 0

      {:ok, average_daily_active_addresses}
    else
      {:error, {:missing_contract, _}} ->
        {:ok, 0}

      {:error, error} ->
        handle_graphql_error("average daily active addresses", project.slug, error)
        {:ok, 0}
    end
  end

  def daily_active_deposits(
        _root,
        %{slug: slug, from: from, to: to, interval: interval},
        _resolution
      ) do
    with {:ok, contract, _} <- Project.contract_info_by_slug(slug),
         {:ok, from, to, interval} <-
           calibrate_interval(
             DailyActiveDeposits,
             contract,
             from,
             to,
             interval,
             @one_hour_in_seconds,
             @datapoints
           ),
         {:ok, active_deposits} <-
           DailyActiveDeposits.active_deposits(contract, from, to, interval) do
      {:ok, active_deposits}
    else
      {:error, error} ->
        {:error, handle_graphql_error("Daily Active Deposits", slug, error)}
    end
  end

  def realized_value(
        _root,
        %{slug: slug, from: from, to: to, interval: interval},
        _resolution
      ) do
    case RealizedValue.realized_value(slug, from, to, interval) do
      {:ok, realized_value} ->
        {:ok, realized_value}

      {:error, error} ->
        {:error, handle_graphql_error("Realized Value", slug, error)}
    end
  end

  def nvt_ratio(
        _root,
        %{slug: slug, from: from, to: to, interval: interval},
        _resolution
      ) do
    with {:ok, nvt_ratio} <- NVT.nvt_ratio(slug, from, to, interval) do
      {:ok, nvt_ratio}
    else
      {:error, error} ->
        {:error, handle_graphql_error("NVT Ratio", slug, error)}
    end
  end

  def assets_held_by_address(_root, %{address: address}, _resolution) do
    HistoricalBalance.assets_held_by_address(address)
    |> case do
      {:ok, result} ->
        # We do this, because many contracts emit a transfer
        # event when minting new tokens by setting 0x00...000
        # as the from address, hence 0x00...000 is "sending"
        # tokens it does not have which leads to "negative" balance

        result =
          result
          |> Enum.reject(fn %{balance: balance} -> balance < 0 end)

        {:ok, result}

      {:error, error} ->
        {:error,
         handle_graphql_error("Assets held by address", address, error, description: "address")}
    end
  end

  def historical_balance(
        _root,
        %{slug: slug, from: from, to: to, interval: interval, address: address},
        _resolution
      ) do
    case HistoricalBalance.historical_balance(address, slug, from, to, interval) do
      {:ok, result} ->
        {:ok, result}

      {:error, error} ->
        {:error, handle_graphql_error("Historical Balances", slug, error)}
    end
  end

  def percent_of_token_supply_on_exchanges(
        _root,
        %{slug: slug, from: from, to: to, interval: interval},
        _resolution
      ) do
    case PercentOfTokenSupplyOnExchanges.percent_on_exchanges(slug, from, to, interval) do
      {:ok, percent_tokens_on_exchanges} ->
        {:ok, percent_tokens_on_exchanges}

      {:error, error} ->
        {:error, handle_graphql_error("Percent of Token Supply on Exchanges", slug, error)}
    end
  end

  def share_of_deposits(
        _root,
        %{slug: slug, from: from, to: to, interval: interval},
        _resolution
      ) do
    with {:ok, contract, _} <- Project.contract_info_by_slug(slug),
         {:ok, from, to, interval} <-
           calibrate_interval(
             ShareOfDeposits,
             contract,
             from,
             to,
             interval,
             @one_hour_in_seconds,
             @datapoints
           ),
         {:ok, share_of_deposits} <-
           ShareOfDeposits.share_of_deposits(contract, from, to, interval) do
      {:ok, share_of_deposits}
    else
      {:error, {:missing_contract, error_msg}} ->
        {:error, error_msg}

      {:error, error} ->
        {:error, handle_graphql_error("Share of Deposits", slug, error)}
    end
  end
end
