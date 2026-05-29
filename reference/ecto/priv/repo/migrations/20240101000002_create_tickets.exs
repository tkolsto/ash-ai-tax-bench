defmodule Bench.Repo.Migrations.CreateTickets do
  use Ecto.Migration

  def change do
    create table(:tickets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :subject, :string, null: false
      add :body, :text, null: false
      add :status, :string, null: false, default: "open"
      add :priority, :string, null: false, default: "medium"
      add :assignee_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end
  end
end
