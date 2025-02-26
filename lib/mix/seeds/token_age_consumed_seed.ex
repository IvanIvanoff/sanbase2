defmodule Sanbase.Seeds.TokenAgeConsumedSeed do
  import Sanbase.Seeds.Helpers

  def populate() do
    changesets = [
      make_changeset(contract1(), random_date(), random_non_neg_float()),
      make_changeset(contract1(), random_date(), random_non_neg_float()),
      make_changeset(contract1(), random_date(), random_non_neg_float()),
      make_changeset(contract1(), random_date(), random_non_neg_float()),
      make_changeset(contract1(), random_date(), random_non_neg_float()),
      make_changeset(contract1(), random_date(), random_non_neg_float()),
      make_changeset(contract1(), random_date(), random_non_neg_float()),
      make_changeset(contract1(), random_date(), random_non_neg_float()),
      make_changeset(contract2(), random_date(), random_non_neg_float()),
      make_changeset(contract2(), random_date(), random_non_neg_float()),
      make_changeset(contract2(), random_date(), random_non_neg_float()),
      make_changeset(contract2(), random_date(), random_non_neg_float()),
      make_changeset(contract2(), random_date(), random_non_neg_float()),
      make_changeset(contract2(), random_date(), random_non_neg_float()),
      make_changeset(contract2(), random_date(), random_non_neg_float()),
      make_changeset(contract2(), random_date(), random_non_neg_float()),
      make_changeset(contract2(), random_date(), random_non_neg_float())
    ]

    Enum.map(changesets, &Sanbase.TimescaleRepo.insert/1)
  end

  defp make_changeset(contract, timestamp, token_age_consumed) do
    alias Sanbase.Blockchain.TokenAgeConsumed

    %TokenAgeConsumed{}
    |> TokenAgeConsumed.changeset(%{
      contract_address: contract,
      timestamp: timestamp,
      token_age_consumed: token_age_consumed
    })
  end
end
