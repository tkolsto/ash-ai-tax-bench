defmodule Bench.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :role, Ecto.Enum, values: [:user, :admin], default: :user

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :role])
    |> validate_required([:email, :role])
    |> unique_constraint(:email)
  end
end
