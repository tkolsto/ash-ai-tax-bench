defmodule BenchWeb.Router do
  use BenchWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", BenchWeb do
    pipe_through :api
  end
end
