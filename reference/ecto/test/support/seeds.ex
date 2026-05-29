defmodule Bench.Seeds do
  @moduledoc """
  Test seed helpers used by the acceptance suite. They delegate user creation to
  `Bench.TestUsers.create!/1`, which the implementation must provide (see SPEC.md).
  Emails are unique per call so a test can create several users without collision.
  """
  def admin, do: Bench.TestUsers.create!(%{email: uniq("admin"), role: :admin})
  def user, do: Bench.TestUsers.create!(%{email: uniq("user"), role: :user})
  def assignee, do: Bench.TestUsers.create!(%{email: uniq("assignee"), role: :user})

  defp uniq(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}@example.com"
end
