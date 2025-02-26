defmodule Sanbase.Blockchain.TransactionVolume do
  use Ecto.Schema

  import Ecto.Changeset
  alias Sanbase.Timescaledb

  @table Timescaledb.table_name("eth_transaction_volume")

  @primary_key false
  schema @table do
    field(:timestamp, :naive_datetime, primary_key: true)
    field(:contract_address, :string, primary_key: true)
    field(:transaction_volume, :float)
  end

  @doc false
  def changeset(%__MODULE__{} = transaction_volume, attrs \\ %{}) do
    transaction_volume
    |> cast(attrs, [:timestamp, :contract_address, :transaction_volume])
    |> validate_number(:transaction_volume, greater_than_or_equal_to: 0.0)
    |> validate_length(:contract_address, min: 1)
  end

  @spec transaction_volume(String.t(), DateTime.t(), DateTime.t(), String.t(), non_neg_integer()) ::
          {:ok, [any()]} | {:error, String.t()}
  def transaction_volume(contract, from, to, interval, token_decimals \\ 0) do
    args = [from, to, contract]

    """
    SELECT sum(transaction_volume) AS value
    FROM #{@table}
    WHERE timestamp >= $1 AND timestamp <= $2 AND contract_address = $3
    """
    |> Timescaledb.bucket_by_interval(args, interval)
    |> Timescaledb.timescaledb_execute(fn [datetime, transaction_volume] ->
      %{
        datetime: Timescaledb.timestamp_to_datetime(datetime),
        transaction_volume: transaction_volume / :math.pow(10, token_decimals)
      }
    end)
  end

  def transaction_volume!(contract, from, to, interval, token_decimals \\ 0) do
    case transaction_volume(contract, from, to, interval, token_decimals) do
      {:ok, result} -> result
      {:error, error} -> raise(error)
    end
  end

  @spec first_datetime(String.t()) :: {:ok, DateTime.t()} | {:ok, nil}
  def first_datetime(contract) do
    "FROM #{@table} WHERE contract_address = $1"
    |> Timescaledb.first_datetime([contract])
  end
end
