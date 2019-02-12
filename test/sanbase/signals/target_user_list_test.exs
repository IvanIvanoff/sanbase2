defmodule SanbaseWeb.Graphql.UserListTest do
  use Sanbase.DataCase, async: false
  alias Sanbase.UserLists.UserList
  alias Sanbase.Signals.UserTrigger

  import SanbaseWeb.Graphql.TestHelpers
  import Sanbase.Factory

  setup do
    user = insert(:user)

    p1 =
      insert(:project, %{
        name: "Santiment",
        ticker: "SAN",
        coinmarketcap_id: "santiment",
        main_contract_address: "0x123123"
      })

    p2 =
      insert(:project, %{
        name: "Maker",
        ticker: "MKR",
        coinmarketcap_id: "maker",
        main_contract_address: "0x321321321"
      })

    {:ok, user_list} = UserList.create_user_list(user, %{name: "my_user_list", color: :green})

    UserList.update_user_list(%{
      id: user_list.id,
      list_items: [%{project_id: p1.id}, %{project_id: p2.id}]
    })

    [user: user, project1: p1, project2: p2, user_list: user_list]
  end

  test "create trigger with user_list", context do
    trigger_settings = %{
      type: "price_absolute_change",
      target: %{user_list: context.user_list.id},
      channel: "telegram",
      above: 300.0,
      below: 200.0,
      repeating: false
    }

    {:ok, _trigger} =
      UserTrigger.create_user_trigger(context.user, %{is_public: true, settings: trigger_settings})
  end
end
