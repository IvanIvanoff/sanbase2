defmodule Sanbase.Signals.Evaluator do
  @moduledoc ~s"""
  A module that takes a list of triggers and returns the ones that must be triggered
  """

  alias Sanbase.Repo
  alias Sanbase.Signals.Evaluator.Cache
  alias Sanbase.Signals.Trigger

  @doc ~s"""
  Takes a list of triggers and returns its subset that evaluate to true at the given moment.
  """
  @spec run(list()) :: list()
  def run(triggers) do
    triggers
    |> remove_triggers_on_cooldown()
    |> Sanbase.Parallel.pfilter_concurrent(
      &triggered?/1,
      ordered: false,
      max_concurrency: 50,
      timeout: 30_000
    )
    |> mark_as_triggered()
  end

  defp remove_triggers_on_cooldown(triggers) do
    triggers |> Enum.reject(&Trigger.has_cooldown?/1)
  end

  defp mark_as_triggered(triggers) do
    triggers
    |> Repo.update_all(set: [last_triggered: Timex.now()])
  end

  defp triggered?(trigger) do
    Cache.get_or_store(
      Trigger.cache_key(trigger),
      fn -> Trigger.triggered?(trigger) end
    )
  end
end
