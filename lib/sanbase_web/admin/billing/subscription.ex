defmodule Sanbase.ExAdmin.Billing.Subscription do
  use ExAdmin.Register

  register_resource Sanbase.Billing.Subscription do
    action_items(only: [:show, :edit, :test])

    query do
      %{
        all: [preload: [:user, plan: [:product]]]
      }
    end

    index do
      column(:id, link: true)
      column(:stripe_id)
      column(:status)
      column(:current_period_end)
      column(:cancel_at_period_end)
      column(:user, link: true)
      column(:plan, link: true)

      column("Product", fn subscription ->
        subscription.plan.product.name
      end)
    end

    show _subscription do
      attributes_table do
        row(:id)
        row(:stripe_id)
        row(:status)
        row(:current_period_end)
        row(:cancel_at_period_end)
        row(:user, link: true)
        row(:plan, link: true)

        row("Product", fn subscription ->
          subscription.plan.product.name
        end)
      end
    end
  end
end
