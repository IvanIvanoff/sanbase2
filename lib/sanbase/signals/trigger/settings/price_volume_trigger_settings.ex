defmodule Sanbase.Signal.Trigger.PriceVolumeDifferenceTriggerSettings do
  use Vex.Struct

  import Sanbase.{Validation, Signal.Validation}
  import Sanbase.Signal.Utils

  alias __MODULE__
  alias Sanbase.Model.Project
  alias Sanbase.TechIndicators.PriceVolumeDifference

  @derive {Jason.Encoder, except: [:filtered_target, :payload, :triggered?]}
  @trigger_type "price_volume_difference"
  @enforce_keys [:type, :target, :channel, :threshold]

  defstruct type: @trigger_type,
            target: nil,
            filtered_target: %{list: []},
            channel: nil,
            threshold: 0.002,
            aggregate_interval: "1d",
            window_type: "bohman",
            approximation_window: 14,
            comparison_window: 7,
            triggered?: false,
            payload: nil

  validates(:target, &valid_target?/1)
  validates(:channel, &valid_notification_channel?/1)
  validates(:threshold, &valid_threshold?/1)

  @typedoc ~s"""
  threshold - the sensitivity of the trigger. Defaults to 0.002
  aggregate_interval - The interval at which the price and volume are aggregated.
    Defaults to 1d
  window_type - Window type for calculating window weights.
    See https://docs.scipy.org/doc/scipy/reference/signal.html#window-functions
  approximation_window - Window for calculating the moving average for a point
    in number of data points.
  comparison_window - window used for calculating the previous data using MA for
    a data point. It is used for calculating increase/decrease in values in number
    of data points.
  """
  @type t :: %__MODULE__{
          type: Type.trigger_type(),
          target: Type.complex_target(),
          filtered_target: Type.filtered_target(),
          channel: Type.channel(),
          threshold: Type.threshold(),
          aggregate_interval: Type.time(),
          window_type: nil,
          approximation_window: nil,
          comparison_window: nil,
          triggered?: boolean(),
          payload: Type.payload()
        }

  @spec type() :: Type.trigger_type()
  def type(), do: @trigger_type

  def get_data(%__MODULE__{filtered_target: %{list: target_list}} = settings)
      when is_list(target_list) do
    target_list
    |> Enum.map(fn slug -> get_data_for_single_project(slug, settings) end)
  end

  def get_data_for_single_project(slug, settings) when is_binary(slug) do
    project = Project.by_slug(slug)

    # return only the last result
    result =
      PriceVolumeDifference.price_volume_diff(
        project,
        "USD",
        Timex.shift(Timex.now(), days: -14),
        Timex.now(),
        settings.aggregate_interval,
        settings.window_type,
        settings.approximation_window,
        settings.comparison_window,
        1
      )
      |> case do
        {:ok, result} -> {:ok, result |> List.first()}
        error -> error
      end

    {slug, result}
  end

  defimpl Sanbase.Signal.Settings, for: PriceVolumeDifferenceTriggerSettings do
    def triggered?(%PriceVolumeDifferenceTriggerSettings{triggered?: triggered}), do: triggered

    def evaluate(%PriceVolumeDifferenceTriggerSettings{} = settings, _trigger) do
      case PriceVolumeDifferenceTriggerSettings.get_data(settings) do
        list when is_list(list) and list != [] ->
          build_result(list, settings)

        _ ->
          %PriceVolumeDifferenceTriggerSettings{settings | triggered?: false}
      end
    end

    def cache_key(%PriceVolumeDifferenceTriggerSettings{} = settings) do
      construct_cache_key([
        settings.threshold,
        settings.aggregate_interval,
        settings.window_type,
        settings.approximation_window,
        settings.comparison_window
      ])
    end

    defp build_result(
           list,
           %PriceVolumeDifferenceTriggerSettings{threshold: threshold} = settings
         ) do
      payload =
        Enum.reduce(list, %{}, fn
          {slug, {:ok, %{price_volume_diff: price_volume_diff}}}, acc
          when price_volume_diff >= threshold ->
            Map.put(acc, slug, payload(slug, settings, price_volume_diff))

          _, acc ->
            acc
        end)

      %PriceVolumeDifferenceTriggerSettings{
        settings
        | triggered?: payload != %{},
          payload: payload
      }
    end

    defp payload(slug, _settings, _price_volume_diff) do
      project = Sanbase.Model.Project.by_slug(slug)

      """
      The price and volume of **#{project.name}** have diverged - the price is
      increasing while the volume is decreasing.

      More info here: #{Sanbase.Model.Project.sanbase_link(project)}
      ![PriceVolume chart over the past 90 days](#{chart_url(project, :volume)})
      """
    end
  end
end
