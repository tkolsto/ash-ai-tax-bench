defmodule Support.Comment do
  @moduledoc """
  A comment on a support ticket, authored by a user.
  """
  use Ash.Resource,
    otp_app: :bench,
    domain: Support,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "comments"
    repo Bench.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:body, :ticket_id, :author_id]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      constraints min_length: 1
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :ticket, Support.Ticket do
      attribute_type :uuid
      allow_nil? false
      public? true
    end

    belongs_to :author, Bench.Accounts.User do
      attribute_type :uuid
      public? true
    end
  end
end
