defmodule SanbaseWeb.Graphql.Resolvers.TokenBurnRateResolver do
  use Tesla

  import Sanbase.Utils, only: [parse_config_value: 1]

  plug(Tesla.Middleware.BaseUrl, get_config(:url))
  plug(Tesla.Middleware.Logger)

  def burn_rate(_root, %{ticker: ticker, from: from, to: to}, _resolution) do
    from_unix = DateTime.to_unix(from, :seconds)
    to_unix = DateTime.to_unix(to, :seconds)

    case get("/burn_rate?ticker=#{ticker}&from_timestamp=#{from_unix}&to_timestamp=#{to_unix}") do
      %Tesla.Env{status: 200, body: body} ->
        {:ok, result} = Code.string_to_quoted(body)

        result = result
        |> Enum.map(fn [timestamp, br] = arg ->
          %{datetime: DateTime.from_unix!(timestamp), burn_rate: Decimal.new(br)}
        end)

        {:ok, result}

      _ ->
        {:error, "Cannot fetch burn rate data for ticker #{ticker}"}
    end
  end

  defp get_config(key) do
    Application.fetch_env!(:sanbase, __MODULE__)
    |> Keyword.get(key)
    |> parse_config_value()
  end
end