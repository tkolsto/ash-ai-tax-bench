defmodule Support.Ticket do
  @moduledoc """
  A support ticket. Transitions (`:close`, `:reopen`) are modeled as dedicated
  update actions with guard validations, and authorization is enforced by
  policies that read the actor passed into the action.
  """
  use Ash.Resource,
    otp_app: :bench,
    domain: Support,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query

  sqlite do
    table "tickets"
    repo Bench.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:subject, :body, :priority, :assignee_id]
    end

    read :by_status do
      argument :status, :atom, allow_nil?: false
      filter expr(status == ^arg(:status))
    end

    update :close do
      # The validation reads the current record state, so it cannot be atomic.
      require_atomic? false

      validate attribute_in(:status, [:open, :pending]),
        message: "can only close an open or pending ticket"

      change set_attribute(:status, :closed)
    end

    update :reopen do
      require_atomic? false

      validate attribute_equals(:status, :closed),
        message: "can only reopen a closed ticket"

      change set_attribute(:status, :open)
    end
  end

  policies do
    # Reads and creates are open in this domain; the actor only gates transitions.
    policy action_type([:read, :create]) do
      authorize_if always()
    end

    # Close: the ticket's assignee OR an admin.
    policy action(:close) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if relates_to_actor_via(:assignee)
    end

    # Reopen: admins only.
    policy action(:reopen) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :subject, :string do
      allow_nil? false
      constraints min_length: 5, max_length: 140
      public? true
    end

    attribute :body, :string do
      allow_nil? false
      constraints min_length: 1
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:open, :pending, :closed]
      default :open
      allow_nil? false
      public? true
    end

    attribute :priority, :atom do
      constraints one_of: [:low, :medium, :high]
      default :medium
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :assignee, Bench.Accounts.User do
      attribute_type :uuid
      public? true
    end

    has_many :comments, Support.Comment do
      public? true
    end
  end
end
