defmodule Support do
  @moduledoc """
  The Support domain — manages tickets and comments.

  This is an `Ash.Domain`. The six public boundary functions required by the spec
  are implemented as thin wrappers around resource actions exposed via code
  interfaces, so that we can normalize Ash's return values to the simple
  `{:ok, value} | {:error, reason}` contract the acceptance suite expects
  (notably `{:error, :not_found}` for an unknown ticket id).
  """
  use Ash.Domain, otp_app: :bench

  resources do
    resource Support.Ticket do
      # Internal code interfaces (prefixed `i_`) so they don't collide with the
      # public boundary functions defined below in this module.
      define :i_create_ticket, action: :create
      define :i_list_tickets, action: :read
      define :i_list_tickets_by_status, action: :by_status, args: [:status]
      define :i_fetch_ticket, action: :read, get_by: [:id]
      define :i_close, action: :close
      define :i_reopen, action: :reopen
    end

    resource Support.Comment do
      define :i_create_comment, action: :create
    end
  end

  @doc """
  Creates a ticket. Validations and defaults live on the `:create` action.
  """
  def create_ticket(attrs, opts \\ []) do
    i_create_ticket(attrs, to_action_opts(opts))
  end

  @doc """
  Lists tickets, optionally filtered by `opts[:status]`.
  """
  def list_tickets(opts \\ []) do
    action_opts = to_action_opts(opts)

    case Keyword.get(opts, :status) do
      nil -> i_list_tickets(action_opts)
      status -> i_list_tickets_by_status(status, action_opts)
    end
  end

  @doc """
  Gets a ticket by id with `comments` loaded. Unknown id -> `{:error, :not_found}`.
  """
  def get_ticket(id, opts \\ []) do
    action_opts = opts |> to_action_opts() |> Keyword.put(:load, [:comments])

    case i_fetch_ticket(id, action_opts) do
      {:ok, ticket} -> {:ok, ticket}
      {:error, error} -> {:error, normalize_reason(error)}
    end
  end

  @doc """
  Adds a comment authored by `opts[:actor]` to the ticket. Unknown ticket or
  invalid body -> `{:error, _}` and nothing is persisted.
  """
  def add_comment(ticket_id, attrs, opts \\ []) do
    actor = Keyword.get(opts, :actor)

    case i_fetch_ticket(ticket_id, authorize?: false) do
      {:ok, _ticket} ->
        attrs
        |> Map.put(:ticket_id, ticket_id)
        |> Map.put(:author_id, actor && actor.id)
        |> i_create_comment(to_action_opts(opts))

      {:error, error} ->
        {:error, normalize_reason(error)}
    end
  end

  @doc """
  Closes a ticket (`:open`/`:pending` -> `:closed`). Actor must be the assignee or
  an admin; an invalid transition or unauthorized actor returns `{:error, _}`.
  """
  def close_ticket(id, opts \\ []) do
    update_ticket(id, &i_close/2, opts)
  end

  @doc """
  Reopens a ticket (`:closed` -> `:open`). Admin only.
  """
  def reopen_ticket(id, opts \\ []) do
    update_ticket(id, &i_reopen/2, opts)
  end

  # --- helpers ---

  # Loads the ticket (bypassing read authorization so the transition policy is
  # the only gate), then runs the given update interface with the actor.
  defp update_ticket(id, action_fun, opts) do
    case i_fetch_ticket(id, authorize?: false) do
      {:ok, ticket} -> action_fun.(ticket, to_action_opts(opts))
      {:error, error} -> {:error, normalize_reason(error)}
    end
  end

  # Only forward :actor and :authorize? from the caller's opts into the action.
  defp to_action_opts(opts) do
    Keyword.take(opts, [:actor, :authorize?])
  end

  # Map Ash's NotFound errors to the bare `:not_found` atom the suite expects;
  # leave every other error untouched.
  defp normalize_reason(%Ash.Error.Query.NotFound{}), do: :not_found

  defp normalize_reason(%Ash.Error.Invalid{errors: errors} = error) do
    if Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1)) do
      :not_found
    else
      error
    end
  end

  defp normalize_reason(other), do: other
end
