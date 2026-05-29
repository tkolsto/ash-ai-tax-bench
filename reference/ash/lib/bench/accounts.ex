defmodule Bench.Accounts do
  @moduledoc """
  The Accounts domain — owns the `User` resource used as the actor in Support actions.
  """
  use Ash.Domain, otp_app: :bench

  resources do
    resource Bench.Accounts.User do
      define :create_user, action: :create
      define :get_user, action: :read, get_by: [:id]
    end
  end
end
