defmodule Sanbase.Signal.Utils do
  alias Sanbase.Math

  @epsilon 1.0e-6

  @doc ~s"""
  Calculate the % change that occured between the first and the second arguments

    ## Examples

      iex> Sanbase.Signal.Utils.percent_change(1.0, 2.0)
      100.0

      iex> Sanbase.Signal.Utils.percent_change(1.0, 1.05)
      5.0

      iex> Sanbase.Signal.Utils.percent_change(0, 2.0)
      0.0

      iex> Sanbase.Signal.Utils.percent_change(2.0, 1.0)
      -50.0

      iex> Sanbase.Signal.Utils.percent_change(2.0, 0.0)
      -100.0

      iex> Sanbase.Signal.Utils.percent_change(2.0, -1)
      -150.0

      iex> Sanbase.Signal.Utils.percent_change(10.0, 10.0)
      0.0
  """
  def percent_change(0, _current_daa), do: 0.0
  def percent_change(nil, _current_daa), do: 0.0

  def percent_change(previous, _current_daa)
      when is_number(previous) and previous <= @epsilon,
      do: 0

  def percent_change(previous, current) when is_number(previous) and is_number(current) do
    Float.round((current - previous) / previous * 100, 2)
  end

  def chart_url(project, type) do
    Sanbase.Chart.build_embedded_chart(
      project,
      Timex.shift(Timex.now(), days: -90),
      Timex.now(),
      chart_type: type
    )
    |> case do
      [%{image: %{url: chart_url}}] -> chart_url
      _ -> nil
    end
  end

  @doc ~s"""
  Round the price to 6 digits if it's between 0 and 1.
  Round the price to 2 digits if it's above 1

    ## Examples

      iex> Sanbase.Signal.Utils.round_price(0.1023812093812312)
      0.102381

      iex> Sanbase.Signal.Utils.round_price(0.5)
      0.5

      iex> Sanbase.Signal.Utils.round_price(0.50000)
      0.5

      iex> Sanbase.Signal.Utils.round_price(5.012412412)
      5.01

      iex> Sanbase.Signal.Utils.round_price(5)
      5.0
  """
  def round_price(price) when is_number(price) and price > 0 and price < 1 do
    Math.to_float(price) |> Float.round(6)
  end

  def round_price(price) when is_number(price) and price >= 1 do
    Math.to_float(price) |> Float.round(2)
  end

  @doc ~s"""
  Construct a unique key by a given list of terms

    ## Examples

      iex> Sanbase.Signal.Utils.construct_cache_key([1,2,3]) != Sanbase.Signal.Utils.construct_cache_key([2,1,3])
      true

      iex> Sanbase.Signal.Utils.construct_cache_key([1,2,3]) == Sanbase.Signal.Utils.construct_cache_key([1,2,3])
      true

      iex> Sanbase.Signal.Utils.construct_cache_key([1,2,3]) |> is_binary()
      true
  """
  def construct_cache_key(keys) when is_list(keys) do
    data = keys |> Jason.encode!()

    :crypto.hash(:sha256, data)
    |> Base.encode16()
    |> binary_part(0, 32)
  end
end
