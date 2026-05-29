defmodule Bench.Accounts.User do
  @moduledoc """
  A user of the system. Acts as the actor for Support actions.
  """
  use Ash.Resource,
    otp_app: :bench,
    domain: Bench.Accounts,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "users"
    repo Bench.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:email, :role]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string do
      allow_nil? false
      public? true
    end

    attribute :role, :atom do
      constraints one_of: [:user, :admin]
      default :user
      allow_nil? false
      public? true
    end

    timestamps()
  end

  identities do
    identity :unique_email, [:email]
  end
end
