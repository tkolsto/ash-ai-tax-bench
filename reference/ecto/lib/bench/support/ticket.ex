defmodule Bench.Support.Ticket do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tickets" do
    field :subject, :string
    field :body, :string
    field :status, Ecto.Enum, values: [:open, :pending, :closed], default: :open
    field :priority, Ecto.Enum, values: [:low, :medium, :high], default: :medium
    belongs_to :assignee, Bench.Accounts.User
    has_many :comments, Bench.Support.Comment

    timestamps()
  end

  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:subject, :body, :status, :priority, :assignee_id])
    |> validate_required([:subject, :body])
    |> validate_length(:subject, min: 5, max: 140)
    |> validate_length(:body, min: 1)
  end

  def close_changeset(ticket) do
    ticket
    |> change(status: :closed)
  end

  def reopen_changeset(ticket) do
    ticket
    |> change(status: :open)
  end
end
