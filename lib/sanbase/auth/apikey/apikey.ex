defmodule Sanbase.Auth.Apikey do
  @moduledoc ~s"""
  Apikey combines and exposes in a transparent manner all the operations with the
  apikeys.

  Let's get some of the terminology straight:
  - User Token (or simply token) is a random string saved plain text in the database.
  The UT *is not* not the apikey and the apikey cannot be generated by knowing only the UT
  - Apikey is generated by a secret key and a UT. The enduser gets this apikey that will
  be used in the communication. By an apikey we can retrieve the owner (user) of it.
  """

  require Logger

  alias Sanbase.Auth.{
    Hmac,
    UserApikeyToken,
    User
  }

  defguard is_non_empty_string(str) when is_binary(str) and str != ""

  @doc ~s"""
  Returns the User struct connected to the given apikey.
  Split the apikey by "_" and use the first part as a user id. Look for all
  user tokens for that ID and check if the apikey is generated from any of the
  tokens
  """
  @spec apikey_to_user(String.t()) :: {:ok, %User{}} | {:error, String.t()}
  def apikey_to_user(apikey) do
    with {:ok, {token, _rest}} <- Hmac.split_apikey(apikey),
         {:valid?, true} <- {:valid?, Hmac.apikey_valid?(token, apikey)},
         {:user?, {:ok, user}} <- {:user?, UserApikeyToken.user_by_token(token)} do
      {:ok, user}
    else
      {:valid?, false} ->
        {:error, "Apikey '#{apikey}' is not valid"}

      {:user?, _} ->
        {:error, "Apikey '#{apikey}' is not valid"}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc ~s"""
  Generates a new User Token and stores it in the database.
  Generate the corresponding Apikey and return it.
  """
  @spec generate_apikey(%User{}) :: {:ok, String.t()} | {:error | String.t()}
  def generate_apikey(%User{id: user_id} = user) do
    with token when is_non_empty_string(token) <- Hmac.generate_token(),
         {:ok, _user_apikey_token} <- UserApikeyToken.add_user_token(user, token),
         apikey when is_non_empty_string(apikey) <- Hmac.generate_apikey(token) do
      {:ok, apikey}
    else
      error ->
        {:error,
         "Error generating new apikey for user with id #{user_id}. Inspecting error: #{
           inspect(error)
         }"}
    end
  end

  @doc ~s"""
  Revokes the given apikey by removing its corresponding
  """
  @spec revoke_apikey(%User{}, String.t()) :: :ok | {:error, String.t()}
  def revoke_apikey(user, apikey) do
    with {:ok, {token, _rest}} <- Hmac.split_apikey(apikey),
         true <- Hmac.apikey_valid?(token, apikey),
         true <- UserApikeyToken.user_has_token?(user, token) do
      UserApikeyToken.remove_user_token(user, token)
      :ok
    else
      error ->
        {:error, "Provided apikey is malformed or not valid. Inspecting error: #{inspect(error)}"}
    end
  end

  @doc ~s"""
  Return a list of all apikeys for a given user
  """
  @spec apikeys_list(%User{}) :: List.t()
  def apikeys_list(%User{id: user_id} = user) do
    with {:ok, tokens} <- UserApikeyToken.user_tokens(user) do
      apikeys =
        Enum.map(tokens, fn token ->
          Hmac.generate_apikey(token)
        end)

      {:ok, apikeys}
    else
      error ->
        err_msg =
          "Error getting apikeys list for user with id #{user_id} Error: #{inspect(error)}"

        Logger.error(err_msg)
        {:error, err_msg}
    end
  end
end
