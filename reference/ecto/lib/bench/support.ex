defmodule Support do
  @moduledoc """
  The Support context — manages tickets and comments.
  """

  import Ecto.Query
  alias Bench.Repo
  alias Bench.Support.Ticket
  alias Bench.Support.Comment

  @doc """
  Creates a ticket with the given attrs.

  Validations:
  - subject: required, length 5..140
  - body: required, non-empty
  - priority: must be in [:low, :medium, :high]

  Defaults: status: :open, priority: :medium
  """
  def create_ticket(attrs, opts \\ []) do
    %Ticket{}
    |> Ticket.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists tickets, optionally filtered by status.
  """
  def list_tickets(opts \\ []) do
    query =
      case Keyword.get(opts, :status) do
        nil ->
          from(t in Ticket)

        status ->
          from(t in Ticket, where: t.status == ^status)
      end

    {:ok, Repo.all(query)}
  end

  @doc """
  Gets a ticket by id with comments preloaded.
  Returns {:error, :not_found} if no ticket exists with that id.
  """
  def get_ticket(id, opts \\ []) do
    case Repo.get(Ticket, id) do
      nil ->
        {:error, :not_found}

      ticket ->
        ticket = Repo.preload(ticket, :comments)
        {:ok, ticket}
    end
  end

  @doc """
  Adds a comment to a ticket.

  - body is required/non-empty
  - author is set from opts[:actor]
  - Returns {:error, _} if ticket not found or body invalid
  """
  def add_comment(ticket_id, attrs, opts \\ []) do
    actor = Keyword.get(opts, :actor)

    case Repo.get(Ticket, ticket_id) do
      nil ->
        {:error, :not_found}

      _ticket ->
        author_id = if actor, do: actor.id, else: nil

        %Comment{}
        |> Comment.changeset(Map.merge(attrs, %{ticket_id: ticket_id, author_id: author_id}))
        |> Repo.insert()
    end
  end

  @doc """
  Closes a ticket.

  - Allowed from :open or :pending -> :closed
  - Actor must be the assignee OR have role :admin
  - Already closed -> {:error, :already_closed}
  - Unauthorized -> {:error, :unauthorized}
  """
  def close_ticket(id, opts \\ []) do
    actor = Keyword.get(opts, :actor)

    case Repo.get(Ticket, id) do
      nil ->
        {:error, :not_found}

      %Ticket{status: :closed} ->
        {:error, :already_closed}

      ticket ->
        if authorized_to_close?(ticket, actor) do
          ticket
          |> Ticket.close_changeset()
          |> Repo.update()
        else
          {:error, :unauthorized}
        end
    end
  end

  @doc """
  Reopens a ticket.

  - Allowed from :closed -> :open
  - Admin only
  - Non-admin -> {:error, :unauthorized}
  - Non-closed -> {:error, :invalid_transition}
  """
  def reopen_ticket(id, opts \\ []) do
    actor = Keyword.get(opts, :actor)

    case Repo.get(Ticket, id) do
      nil ->
        {:error, :not_found}

      %Ticket{status: status} when status != :closed ->
        {:error, :invalid_transition}

      ticket ->
        if actor && actor.role == :admin do
          ticket
          |> Ticket.reopen_changeset()
          |> Repo.update()
        else
          {:error, :unauthorized}
        end
    end
  end

  # Private helpers

  defp authorized_to_close?(ticket, actor) do
    cond do
      is_nil(actor) -> false
      actor.role == :admin -> true
      ticket.assignee_id == actor.id -> true
      true -> false
    end
  end
end
