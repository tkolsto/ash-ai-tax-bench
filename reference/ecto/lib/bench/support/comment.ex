defmodule Bench.Support.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "comments" do
    field :body, :string
    belongs_to :ticket, Bench.Support.Ticket
    belongs_to :author, Bench.Accounts.User

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :ticket_id, :author_id])
    |> validate_required([:body, :ticket_id])
    |> validate_length(:body, min: 1)
  end
end
