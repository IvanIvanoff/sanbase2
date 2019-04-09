defmodule Sanbase.Auth.Settings do
  use Ecto.Schema
  import Ecto.Changeset

  @newsletter_subscription_types ["DAILY", "WEEKLY", "OFF"]

  embedded_schema do
    field(:signal_notify_email, :boolean, default: false)
    field(:signal_notify_telegram, :boolean, default: false)
    field(:telegram_chat_id, :integer)
    field(:has_telegram_connected, :boolean, virtual: true)
    field(:newsletter_subscription, :string, default: "WEEKLY")
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [
      :signal_notify_email,
      :signal_notify_telegram,
      :telegram_chat_id
    ])
    |> normalize_newsletter_subscription(
      :newsletter_subscription,
      params[:newsletter_subscription]
    )
    |> validate_change(:newsletter_subscription, &validate_subscription_type/2)
  end

  defp normalize_newsletter_subscription(changeset, field, nil), do: changeset

  defp normalize_newsletter_subscription(changeset, field, value) do
    put_change(
      changeset,
      field,
      value |> Atom.to_string() |> String.upcase()
    )
  end

  defp validate_subscription_type(_, nil), do: []
  defp validate_subscription_type(_, type) when type in @newsletter_subscription_types, do: []

  defp validate_subscription_type(_, type) do
    [
      newsletter_subscription:
        "Type not in allowed types: #{inspect(@newsletter_subscription_types)}"
    ]
  end
end
