defmodule Sanbase.Auth.UserTest do
  use Sanbase.DataCase, async: false

  import Mockery

  alias Sanbase.Auth.{User, EthAccount}

  test "san balance cache is stale when the cache is never updated" do
    user = %User{san_balance_updated_at: nil}

    assert User.san_balance_cache_stale?(user)
  end

  test "san balance cache is stale when the san balance was updated 10 min ago" do
    user = %User{san_balance_updated_at: Timex.shift(Timex.now(), minutes: -10)}

    assert User.san_balance_cache_stale?(user)
  end

  test "san balance cache is not stale when the san balance was updated 5 min ago" do
    user = %User{san_balance_updated_at: Timex.shift(Timex.now(), minutes: -5)}

    refute User.san_balance_cache_stale?(user)
  end

  test "update_san_balance_changeset is returning a changeset with updated san balance" do
    mock(Sanbase.InternalServices.Ethauth, :san_balance, Decimal.new(5))

    user = %User{san_balance: 0, eth_accounts: [%EthAccount{address: "0x000000000001"}]}

    changeset = User.update_san_balance_changeset(user)

    assert changeset.changes[:san_balance] == Decimal.new(5)
    assert Timex.diff(Timex.now(), changeset.changes[:san_balance_updated_at], :seconds) == 0
  end

  test "san_balance! does not update the balance if the balance cache is not stale" do
    user = %User{san_balance_updated_at: Timex.now(), san_balance: Decimal.new(5)}

    assert User.san_balance!(user) == Decimal.new(5)
  end

  test "san_balance! updates the balance if the balance cache is stale" do
    user =
      %User{
        san_balance_updated_at: Timex.shift(Timex.now(), minutes: -10),
        salt: User.generate_salt()
      }
      |> Repo.insert!()

    mock(Sanbase.InternalServices.Ethauth, :san_balance, Decimal.new(10))

    %EthAccount{address: "0x000000000001", user_id: user.id}
    |> Repo.insert!()

    user =
      Repo.get(User, user.id)
      |> Repo.preload(:eth_accounts)

    assert User.san_balance!(user) == Decimal.new(10)

    user = Repo.get(User, user.id)
    assert Timex.diff(Timex.now(), user.san_balance_updated_at, :seconds) == 0
  end

  test "find_or_insert_by_email when the user does not exist" do
    {:ok, user} = User.find_or_insert_by_email("test@example.com", "john_snow")

    assert user.email == "test@example.com"
    assert user.username == "john_snow"
  end

  test "find_or_insert_by_email when the user exists" do
    existing_user =
      %User{email: "test@example.com", username: "cersei", salt: User.generate_salt()}
      |> Repo.insert!()

    {:ok, user} = User.find_or_insert_by_email(existing_user.email, "john_snow")

    assert user.id == existing_user.id
    assert user.email == existing_user.email
    assert user.username == existing_user.username
  end

  test "update_email_token updates the email_token and the email_token_generated_at" do
    user =
      %User{salt: User.generate_salt()}
      |> Repo.insert!()

    {:ok, user} = User.update_email_token(user)

    assert user.email_token != nil
    assert Timex.diff(Timex.now(), user.email_token_generated_at, :seconds) == 0
  end
end
