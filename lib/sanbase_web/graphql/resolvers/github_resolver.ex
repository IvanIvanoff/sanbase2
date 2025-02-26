defmodule SanbaseWeb.Graphql.Resolvers.GithubResolver do
  require Logger

  alias SanbaseWeb.Graphql.Helpers.Utils
  alias Sanbase.Model.Project

  def dev_activity(
        _root,
        %{
          slug: slug,
          from: from,
          to: to,
          interval: interval,
          transform: transform,
          moving_average_interval_base: moving_average_interval_base
        },
        _resolution
      ) do
    with {:ok, github_organizations} <- Project.github_organizations(slug),
         {:ok, result} <-
           Sanbase.Clickhouse.Github.dev_activity(
             github_organizations,
             from,
             to,
             interval,
             transform,
             moving_average_interval_base
           ) do
      {:ok, result}
    else
      {:error, {:github_link_error, _error}} ->
        {:ok, []}

      error ->
        Logger.error("Cannot fetch github activity for #{slug}. Reason: #{inspect(error)}")
        {:error, "Cannot fetch github activity for #{slug}"}
    end
  end

  def github_activity(
        _root,
        %{
          slug: slug,
          from: from,
          to: to,
          interval: interval,
          transform: transform,
          moving_average_interval_base: moving_average_interval_base
        },
        _resolution
      ) do
    with {:ok, github_organizations} <- Project.github_organizations(slug),
         {:ok, from, to, interval} <-
           Utils.calibrate_interval(
             Sanbase.Clickhouse.Github,
             github_organizations,
             from,
             to,
             interval,
             24 * 60 * 60
           ),
         {:ok, result} <-
           Sanbase.Clickhouse.Github.github_activity(
             github_organizations,
             from,
             to,
             interval,
             transform,
             moving_average_interval_base
           ) do
      {:ok, result}
    else
      {:error, {:github_link_error, _error}} ->
        {:ok, []}

      error ->
        Logger.error("Cannot fetch github activity for #{slug}. Reason: #{inspect(error)}")
        {:error, "Cannot fetch github activity for #{slug}"}
    end
  end

  def available_repos(_root, _args, _resolution) do
    {:ok, Project.List.project_slugs_with_github_link()}
  end
end
