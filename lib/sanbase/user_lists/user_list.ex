defmodule Sanbase.UserList do
  @moduledoc ~s"""
  Module for working with lists of projects.

  A watchlist (or user list) is a user created list of projects. The projects
  in the list can be some concrete projects, they can be dynamically determined
  by a function or the combination of both.

  The list of some concrete slugs is used when a user wants to create a list of
  projects they are interested in. It can contain any project.

  The watchlist defined by a function is being used when a watchlist can change
  frequently according to some rules. Examples for such lists are having a watchlist
  of the top 50 ERC20 projects or all projects with a market segment "stablecoin"
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Sanbase.Auth.User
  alias Sanbase.UserList.ListItem
  alias Sanbase.WatchlistFunction
  alias Sanbase.Repo
  alias Sanbase.Timeline.TimelineEvent

  schema "user_lists" do
    field(:name, :string)
    field(:slug, :string)
    field(:is_public, :boolean, default: false)
    field(:color, ColorEnum, default: :none)
    field(:function, WatchlistFunction, default: %WatchlistFunction{})

    belongs_to(:user, User)

    has_one(:featured_item, Sanbase.FeaturedItem, on_delete: :delete_all)
    has_many(:list_items, ListItem, on_delete: :delete_all, on_replace: :delete)
    has_many(:timeline_events, TimelineEvent, on_delete: :delete_all)

    timestamps()
  end

  # ex_admin needs changeset function
  def changeset(user_list, attrs \\ %{}) do
    update_changeset(user_list, attrs)
  end

  def create_changeset(%__MODULE__{} = user_list, attrs \\ %{}) do
    user_list
    |> cast(attrs, [:user_id, :name, :slug, :is_public, :color, :function])
    |> validate_required([:name, :user_id])
    |> unique_constraint(:slug)
  end

  def update_changeset(%__MODULE__{id: _id} = user_list, attrs \\ %{}) do
    user_list
    |> cast(attrs, [:name, :slug, :is_public, :color, :function])
    |> cast_assoc(:list_items)
    |> validate_required([:name])
    |> unique_constraint(:slug)
  end

  def by_id(id) do
    from(ul in __MODULE__, where: ul.id == ^id)
    |> Repo.one()
  end

  def by_slug(slug) when is_binary(slug) do
    from(ul in __MODULE__, where: ul.slug == ^slug)
    |> Repo.one()
  end

  @doc ~s"""
  Return a list of all projects in a watchlist.
  """
  def get_projects(%__MODULE__{function: fun} = user_list) do
    (WatchlistFunction.evaluate(fun) ++ ListItem.get_projects(user_list))
    |> Enum.uniq_by(fn %{id: id} -> id end)
  end

  def create_user_list(%User{id: user_id} = _user, params \\ %{}) do
    %__MODULE__{}
    |> create_changeset(Map.merge(params, %{user_id: user_id}))
    |> Repo.insert()
  end

  def update_user_list(%{id: id} = params) do
    params = update_list_items_params(params, id)

    changeset =
      id
      |> by_id()
      |> Repo.preload(:list_items)
      |> update_changeset(params)

    Repo.update(changeset)
    |> maybe_create_event(changeset, TimelineEvent.update_watchlist_type())
  end

  def remove_user_list(%{id: id}) do
    by_id(id)
    |> Repo.delete()
  end

  def fetch_user_lists(%User{id: id} = _user) do
    query = from(ul in __MODULE__, where: ul.user_id == ^id)
    {:ok, Repo.all(query)}
  end

  def fetch_public_user_lists(%User{id: id} = _user) do
    query =
      from(ul in __MODULE__,
        where: ul.user_id == ^id and ul.is_public == true
      )

    {:ok, Repo.all(query)}
  end

  def fetch_all_public_lists() do
    query =
      from(
        ul in __MODULE__,
        where: ul.is_public == true
      )

    {:ok, Repo.all(query)}
  end

  def user_list(user_list_id, user) do
    query = user_list_query_by_user_id(user)
    {:ok, Repo.get(query, user_list_id)}
  end

  def user_list_by_slug(slug, user) do
    query = user_list_query_by_user_id(user)
    {:ok, Repo.get_by(query, slug: slug)}
  end

  # Private functions

  defp maybe_create_event({:ok, watchlist}, changeset, event_type) do
    TimelineEvent.maybe_create_event_async(event_type, watchlist, changeset)
    {:ok, watchlist}
  end

  defp maybe_create_event(error_result, _, _), do: error_result

  defp user_list_query_by_user_id(%User{id: user_id}) when is_integer(user_id) and user_id > 0 do
    from(ul in __MODULE__, where: ul.is_public == true or ul.user_id == ^user_id)
  end

  defp user_list_query_by_user_id(_) do
    from(dul in __MODULE__, where: dul.is_public == true)
  end

  defp update_list_items_params(%{list_items: list_items} = params, id)
       when is_list(list_items) do
    list_items =
      list_items
      |> Enum.map(fn item -> %{project_id: item.project_id, user_list_id: id} end)

    %{params | list_items: list_items}
  end

  defp update_list_items_params(params, _) when is_map(params), do: params
end
