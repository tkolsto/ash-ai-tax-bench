# Support Ticket domain — implementation spec

Implement an Elixir module `Support` (a context/domain) that manages support tickets,
backed by the database, satisfying the behavior below. A test suite at
`test/support_test.exs` defines the exact expectations; **your task is to make
`mix test` pass.** Do not edit any file under `test/`.

## Entities
- **User** (seeded by tests): `id`, `email`, `role` (`:user` | `:admin`).
- **Ticket**: `id`, `subject` (string), `body` (string), `status`
  (`:open` | `:pending` | `:closed`, default `:open`), `priority`
  (`:low` | `:medium` | `:high`, default `:medium`), `assignee_id` (User, optional),
  timestamps. Has many comments.
- **Comment**: `id`, `body` (string), `ticket_id`, `author_id` (User), timestamps.

## Public functions (the boundary the tests call)
All return `{:ok, value}` or `{:error, reason}`. `opts` may carry `:actor` (a User struct).

- `Support.create_ticket(attrs, opts \\ [])`
  - attrs keys: `subject`, `body`, `priority` (optional), `assignee_id` (optional).
  - Validations: `subject` length 5..140; `body` required/non-empty; `priority`
    in the enum. On any validation failure return `{:error, _}` and persist nothing.
  - Defaults: `status: :open`, `priority: :medium`.
- `Support.list_tickets(opts \\ [])` → `{:ok, [ticket]}`. Supports `opts[:status]` filter.
- `Support.get_ticket(id, opts \\ [])` → `{:ok, ticket}` with `comments` loaded (a list);
  unknown id → `{:error, :not_found}`.
- `Support.add_comment(ticket_id, attrs, opts \\ [])`
  - attrs: `body` (required/non-empty). The comment's author is `opts[:actor]`.
  - invalid/empty body → `{:error, _}`, persist nothing. unknown ticket → `{:error, _}`.
- `Support.close_ticket(id, opts \\ [])`
  - Allowed from `:open` or `:pending` → sets `:closed`.
  - **Authorization:** actor must be the ticket's assignee OR have `role: :admin`.
    Unauthorized → `{:error, _}` and status unchanged.
  - From `:closed` → `{:error, _}` (invalid transition), status unchanged.
- `Support.reopen_ticket(id, opts \\ [])`
  - Allowed from `:closed` → sets `:open`. **Admin only** (`role: :admin`).
  - Non-admin → `{:error, _}`, unchanged. From non-closed → `{:error, _}`, unchanged.

## Test-support requirement
The test suite seeds users through a tiny helper. You MUST provide a module function
`Bench.TestUsers.create!(%{email: String.t(), role: :user | :admin})` that inserts and
returns a User (with `id` and `role` populated). This is used ONLY by the test seeds.

## Notes
- Use the project's already-configured database (SQLite). Generate any needed migrations
  and ensure they run in the test environment (the test setup uses an Ecto SQL sandbox on
  `Bench.Repo`).
- Implement idiomatically for the framework already set up in this project.
