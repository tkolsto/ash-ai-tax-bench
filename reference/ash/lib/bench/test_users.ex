defmodule Bench.TestUsers do
  @moduledoc """
  Test-only helper for seeding users in the acceptance suite.
  """

  @doc """
  Inserts and returns a User with the given email and role. Raises on failure.
  """
  def create!(%{email: email, role: role}) do
    Bench.Accounts.create_user!(%{email: email, role: role}, authorize?: false)
  end
end
