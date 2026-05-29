defmodule Bench.TestUsers do
  @moduledoc """
  Test-only helper for seeding users in the acceptance suite.
  """

  alias Bench.Repo
  alias Bench.Accounts.User

  @doc """
  Inserts and returns a User with the given email and role.
  Raises on failure.
  """
  def create!(%{email: email, role: role}) do
    %User{}
    |> User.changeset(%{email: email, role: role})
    |> Repo.insert!()
  end
end
