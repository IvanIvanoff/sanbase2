defmodule Sanbase.StripeApi do
  @moduledoc """
  Module wrapping communication with Stripe.
  """

  alias Sanbase.Billing.{Product, Plan}
  alias Sanbase.Auth.User

  @type subscription_item :: %{plan: String.t()}
  @type subscription :: %{
          optional(:coupon) => String.t(),
          customer: String.t(),
          items: list(subscription_item)
        }

  def create_customer(%User{username: username, email: email}, card_token) do
    Stripe.Customer.create(%{
      description: username,
      email: email,
      source: card_token
    })
  end

  def update_customer(%User{stripe_customer_id: stripe_customer_id}, card_token) do
    Stripe.Customer.update(stripe_customer_id, %{source: card_token})
  end

  def create_product(%Product{name: name}) do
    Stripe.Product.create(%{name: name, type: "service"})
  end

  def create_plan(%Plan{
        name: name,
        currency: currency,
        amount: amount,
        interval: interval,
        product: %Product{stripe_id: product_stripe_id}
      }) do
    Stripe.Plan.create(%{
      nickname: name,
      currency: currency,
      amount: amount,
      interval: interval,
      product: product_stripe_id
    })
  end

  @spec create_subscription(subscription) ::
          {:ok, %Stripe.Subscription{}} | {:error, %Stripe.Error{}}
  def create_subscription(%{customer: _customer, items: _items} = subscription) do
    Stripe.Subscription.create(subscription)
  end

  def update_subscription(stripe_id, params) do
    Stripe.Subscription.update(stripe_id, params)
  end

  def cancel_subscription(stripe_id) do
    stripe_id
    |> update_subscription(%{cancel_at_period_end: true})
  end

  def get_subscription_first_item_id(stripe_id) do
    stripe_id
    |> retrieve_subscription()
    |> case do
      {:ok, subscription} ->
        item_id =
          subscription.items.data
          |> hd()
          |> Map.get(:id)

        {:ok, item_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def retrieve_subscription(stripe_id) do
    Stripe.Subscription.retrieve(stripe_id)
  end

  def create_coupon(%{percent_off: percent_off, duration: duration}) do
    Stripe.Coupon.create(%{percent_off: percent_off, duration: duration})
  end

  def list_payments(%User{stripe_customer_id: stripe_customer_id})
      when is_binary(stripe_customer_id) do
    Stripe.Charge.list(%{customer: stripe_customer_id})
  end

  def list_payments(_) do
    {:ok, []}
  end
end
