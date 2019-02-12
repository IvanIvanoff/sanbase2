defmodule Sanbase.Signals.Trigger.PriceAbsoluteChangeSettings do
  @moduledoc ~s"""
  PriceAbsoluteChangeSettings configures the settings for a signal that is fired
  when the price of `target` goes higher than `above` or lower than `below`
  """

  @derive Jason.Encoder
  @trigger_type "price_absolute_change"
  @enforce_keys [:type, :target, :channel]
  defstruct type: @trigger_type,
            target: nil,
            channel: nil,
            above: nil,
            below: nil,
            repeating: false,
            triggered?: false,
            payload: nil

  alias Sanbase.Signals.Type

  @type t :: %__MODULE__{
          type: Type.trigger_type(),
          target: Type.complex_target(),
          channel: Type.channel(),
          above: number(),
          below: number(),
          repeating: boolean(),
          triggered?: boolean(),
          payload: Type.payload()
        }

  use Vex.Struct
  import Sanbase.Signals.Utils
  alias __MODULE__
  alias Sanbase.Model.Project
  alias Sanbase.Signals.Evaluator.Cache
  alias Sanbase.UserLists.UserList

  @spec type() :: Type.trigger_type()
  def type(), do: @trigger_type

  defp get_data_by_slug(slug) when is_binary(slug) do
    Cache.get_or_store(
      "#{slug}_last_price",
      fn ->
        Project.by_slug(slug)
        |> Sanbase.Influxdb.Measurement.name_from()
        |> Sanbase.Prices.Store.last_record()
        |> case do
          {:ok, [[_dt, _mcap, _price_btc, price_usd, _vol]]} -> {:ok, price_usd}
          error -> {:error, error}
        end
      end
    )
  end

  def get_data(%__MODULE__{target: target}) when is_binary(target) do
    [{target, get_data_by_slug(target)}]
  end

  def get_data(%__MODULE__{target: target_list}) when is_list(target_list) do
    target_list
    |> Enum.map(fn slug ->
      {slug, get_data_by_slug(slug)}
    end)
  end

  def get_data(%__MODULE__{target: %{user_list: user_list_id}}) do
    %UserList{list_items: list_items} = UserList.by_id(user_list_id)

    list_items
    |> Enum.map(fn %{project_id: id} -> id end)
    |> Project.List.slugs_by_ids()
    |> Enum.map(fn slug ->
      {slug, get_data_by_slug(slug)}
    end)
  end

  defimpl Sanbase.Signals.Settings, for: PriceAbsoluteChangeSettings do
    @spec triggered?(Sanbase.Signals.Trigger.PriceAbsoluteChangeSettings.t()) :: boolean()
    def triggered?(%PriceAbsoluteChangeSettings{triggered?: triggered}), do: triggered

    def evaluate(%PriceAbsoluteChangeSettings{target: target} = settings)
        when is_binary(target) do
      case PriceAbsoluteChangeSettings.get_data(settings) do
        list when list != [] ->
          build_result(list, settings)

        [] ->
          %PriceAbsoluteChangeSettings{
            settings
            | triggered?: false
          }

        _ ->
          %PriceAbsoluteChangeSettings{settings | triggered?: false}
      end
    end

    defp build_result(list, %PriceAbsoluteChangeSettings{above: above, below: below} = settings) do
      payload =
        Enum.reduce(list, %{}, fn
          slug_last_price, acc ->
            case slug_last_price do
              {slug, {:ok, price}} when price >= above ->
                Map.put(acc, slug, payload(settings, price, "above $#{above}"))

              {slug, {:ok, price}} when price <= below ->
                Map.put(acc, slug, payload(settings, price, "below $#{below}"))

              _ ->
                acc
            end
        end)

      if payload != %{} do
        %PriceAbsoluteChangeSettings{
          settings
          | triggered?: true,
            payload: payload
        }
      else
        settings
      end
    end

    @doc ~s"""
    Construct a cache key only out of the parameters that determine the outcome.
    Parameters like `repeating` and `channel` are discarded. The `type` is included
    so different triggers with the same parameter names can be distinguished
    """
    def cache_key(%PriceAbsoluteChangeSettings{} = settings) do
      construct_cache_key([
        settings.type,
        settings.target,
        settings.above,
        settings.below
      ])
    end

    defp chart_url(project) do
      Sanbase.Chart.build_embedded_chart(
        project,
        Timex.shift(Timex.now(), days: -90),
        Timex.now()
      )
      |> case do
        [%{image: %{url: chart_url}}] -> chart_url
        _ -> nil
      end
    end

    defp payload(settings, last_price_usd, message) do
      project = Sanbase.Model.Project.by_slug(settings.target)

      """
      The price of **#{project.name}** is $#{last_price_usd} which is #{message}
      More information for the project you can find here: #{
        Sanbase.Model.Project.sanbase_link(project)
      }
      ![Price chart over the past 90 days](#{chart_url(project)})
      """
    end
  end
end
