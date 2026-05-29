defmodule Bench.Repo do
  use AshSqlite.Repo,
    otp_app: :bench
end
