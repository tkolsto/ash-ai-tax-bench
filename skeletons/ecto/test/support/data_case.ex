defmodule Bench.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Bench.Repo
      import Ecto.Changeset
      import Bench.DataCase
      import Bench.Seeds
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Bench.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
