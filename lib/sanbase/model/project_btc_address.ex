defmodule Sanbase.Model.ProjectBtcAddress do
  use Ecto.Schema
  import Ecto.Changeset
  alias Sanbase.Model.{ProjectBtcAddress, Project, LatestBtcWalletData}

  schema "project_btc_address" do
    field(:address, :string)
    belongs_to(:project, Project)

    belongs_to(
      :latest_btc_wallet_data,
      LatestBtcWalletData,
      foreign_key: :address,
      references: :address,
      define_field: false
    )
  end

  @doc false
  def changeset(%ProjectBtcAddress{} = project_btc_address, attrs \\ %{}) do
    project_btc_address
    |> cast(attrs, [:address, :project_id])
    |> validate_required([:address, :project_id])
    |> update_change(:address, &String.downcase/1)
    |> unique_constraint(:address)
  end
end
