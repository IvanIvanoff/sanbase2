defmodule Sanbase.Billing.Plan.SanbaseAccessChecker do
  @moduledoc ~s"""
  Implement the restrictions for the Sanbase product
  """

  alias Sanbase.Billing.Plan
  alias Sanbase.Signal.UserTrigger

  @signals_limits_upgrade_message """
  You have reached the maximum number of allowed signals for your current subscription plan.
  Please upgrade to PRO subscription plan for unlimited signals.
  """

  @free_plan_stats %{
    historical_data_in_days: 2 * 365,
    realtime_data_cut_off_in_days: 30,
    signals: %{
      limit: 10
    },
    external_data_providers: false,
    sangraphs_access: false
  }

  @basic_plan_stats %{
    historical_data_in_days: 2 * 365,
    realtime_data_cut_off_in_days: 7,
    signals: %{
      limit: 10
    },
    external_data_providers: false,
    sangraphs_access: true
  }

  @pro_plan_stats %{
    historical_data_in_days: 3 * 365,
    realtime_data_cut_off_in_days: 0,
    signals: %{
      limit: :no_limit
    },
    external_data_providers: true,
    sangraphs_access: true
  }

  @enterprise_plan_stats @pro_plan_stats

  def historical_data_in_days(plan, _query) do
    plan_stats(plan)
    |> Map.get(:historical_data_in_days)
  end

  def realtime_data_cut_off_in_days(plan, _query) do
    plan_stats(plan)
    |> Map.get(:realtime_data_cut_off_in_days)
  end

  def signals_limit(plan) do
    plan_stats(plan)
    |> get_in([:signals, :limit])
  end

  def signals_limits_not_reached?(user, subscription) do
    created_signals_count = UserTrigger.triggers_count_for(user)

    subscription.plan
    |> Plan.plan_atom_name()
    |> signals_limit()
    |> case do
      :no_limit ->
        true

      limit when is_integer(limit) and created_signals_count >= limit ->
        false

      _ ->
        true
    end
  end

  def signals_limits_upgrade_message(), do: @signals_limits_upgrade_message

  defp plan_stats(plan) do
    case plan do
      :free -> @free_plan_stats
      :basic -> @basic_plan_stats
      :pro -> @pro_plan_stats
      :enterprise -> @enterprise_plan_stats
    end
  end
end
