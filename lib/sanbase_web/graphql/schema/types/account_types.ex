defmodule SanbaseWeb.Graphql.AccountTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Ecto, repo: Sanbase.Repo

  import SanbaseWeb.Graphql.Cache, only: [cache_resolve: 1]

  alias SanbaseWeb.Graphql.Resolvers.{
    ApikeyResolver,
    AccountResolver,
    EthAccountResolver,
    UserSettingsResolver,
    UserTriggerResolver,
    PostResolver,
    BillingResolver
  }

  object :user do
    field(:id, non_null(:id))
    field(:email, :string)
    field(:username, :string)
    field(:consent_id, :string)
    field(:privacy_policy_accepted, :boolean)
    field(:marketing_accepted, :boolean)
    field(:first_login, :boolean, default_value: false)

    field :permissions, :access_level do
      resolve(&AccountResolver.permissions/3)
    end

    field :san_balance, :float do
      cache_resolve(&AccountResolver.san_balance/3)
    end

    @desc ~s"""
    A list of ethereum addresses owned by the user. A special message needs to be
    signed in order to be confirmed that the address belongs to the user.
    The combined SAN balance of the addresses is used for the `san_balance`
    """
    field(:eth_accounts, list_of(:eth_account), resolve: assoc(:eth_accounts))

    @desc ~s"""
    A list of api keys. They are used by providing `Authorization` header to the
    HTTP request with the value `Apikey <apikey>` (case sensitive). To generate
    or revoke api keys check the `generateApikey` and `revokeApikey` mutations.

    Using an apikey gives access to the queries, but not to the mutations. Every
    api key has the same SAN balance and subsription as the whole account
    """
    field :apikeys, list_of(:string) do
      resolve(&ApikeyResolver.apikeys_list/3)
    end

    field :settings, :user_settings do
      resolve(&UserSettingsResolver.settings/3)
    end

    field :triggers, list_of(:trigger) do
      resolve(&UserTriggerResolver.triggers/3)
    end

    field(:following, list_of(:user_follower), resolve: assoc(:following))
    field(:followers, list_of(:user_follower), resolve: assoc(:followers))

    field :insights, list_of(:post) do
      resolve(&PostResolver.insights/3)
    end

    field :subscriptions, list_of(:subscription_plan) do
      resolve(&BillingResolver.subscriptions/3)
    end

    @desc ~s"""
    The total number of api calls made by the user in a given time range.
    Counts all API calls made either with JWT or API Key authentication
    """
    field :api_calls_history, list_of(:api_call_data) do
      arg(:from, non_null(:datetime))
      arg(:to, non_null(:datetime))
      arg(:interval, :string, default_value: "1d")

      cache_resolve(&AccountResolver.api_calls_history/3)
    end
  end

  object :api_call_data do
    field(:datetime, non_null(:datetime))
    field(:api_calls_count, non_null(:integer))
  end

  @desc ~s"""
  A type describing an Ethereum address. Beside the address itself it returns
  the SAN balance of that address.
  """
  object :eth_account do
    field(:address, non_null(:string))

    field :san_balance, non_null(:integer) do
      cache_resolve(&EthAccountResolver.san_balance/3)
    end
  end

  object :post_author do
    field(:id, non_null(:id))
    field(:username, :string)
  end

  object :login do
    field(:token, non_null(:string))
    field(:user, non_null(:user))
  end

  object :logout do
    field(:success, non_null(:boolean))
  end

  object :email_login_request do
    field(:success, non_null(:boolean))
    field(:first_login, :boolean, default_value: false)
  end

  object :access_level do
    field(:api, non_null(:boolean))
    field(:sanbase, non_null(:boolean))
    field(:spreadsheet, non_null(:boolean))
    field(:sangraphs, non_null(:boolean))
  end

  object :user_follower do
    field(:user_id, non_null(:id))
    field(:follower_id, non_null(:id))
  end
end
