defmodule Sanbase.Signal.Evaluator do
  @moduledoc ~s"""
  A module that takes a list of triggers and returns the ones that are triggered.
  """

  alias Sanbase.Signal.Evaluator.Cache
  alias Sanbase.Signal.{UserTrigger, Trigger}

  require Logger

  @doc ~s"""
  Takes a list of triggers and returns its subset that evaluate to true at the given moment.
  """
  @spec run(list(), String.t() | nil) :: list()
  def run(user_triggers, type \\ nil)

  def run([], _), do: []

  def run(user_triggers, type) do
    Logger.info("Start evaluating #{length(user_triggers)} signals of type #{type}")

    user_triggers
    |> Sanbase.Parallel.map(
      &evaluate/1,
      ordered: false,
      max_concurrency: 100,
      timeout: 30_000
    )
    |> Enum.filter(&triggered?/1)
  end

  defp evaluate(%UserTrigger{trigger: original_trigger} = user_trigger) do
    trigger =
      Cache.get_or_store(
        {original_trigger.last_triggered, Trigger.cache_key(original_trigger)},
        fn -> Trigger.evaluate(original_trigger) end
      )

    # Take only `payload` and `triggered?` from the cache
    %UserTrigger{
      user_trigger
      | trigger: %{
          original_trigger
          | settings: %{
              original_trigger.settings
              | payload: trigger.settings.payload,
                triggered?: trigger.settings.triggered?
            }
        }
    }
  end

  defp triggered?(%UserTrigger{trigger: trigger}) do
    Trigger.triggered?(trigger)
  end
end
