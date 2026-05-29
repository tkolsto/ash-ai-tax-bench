defmodule Bench.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query
  alias Bench.Repo
  alias Bench.Accounts.User

  def get_user(id), do: Repo.get(User, id)

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
