defmodule Sanbase.Auth.UserSettings do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias __MODULE__
  alias Sanbase.Auth.{User, Settings}
  alias Sanbase.Repo

  schema "user_settings" do
    belongs_to(:user, User)
    embeds_one(:settings, Settings, on_replace: :update)

    timestamps()
  end

  def changeset(%UserSettings{} = user_settings, attrs \\ %{}) do
    user_settings
    |> cast(attrs, [:user_id])
    |> cast_embed(:settings, required: true, with: &Settings.changeset/2)
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
  end

  def settings_for(%User{id: user_id}) do
    Repo.get_by(UserSettings, user_id: user_id)
    |> case do
      nil ->
        nil

      %UserSettings{} = us ->
        us.settings
    end
  end

  def toggle_notification_channel(%User{id: user_id}, args) do
    Repo.get_by(UserSettings, user_id: user_id)
    |> case do
      %UserSettings{} = us ->
        changeset(us, %{settings: args})

      nil ->
        changeset(%UserSettings{}, %{user_id: user_id, settings: args})
    end
    |> Repo.insert_or_update()
  end
end
