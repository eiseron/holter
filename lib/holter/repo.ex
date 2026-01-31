defmodule Holter.Repo do
  use Ecto.Repo,
    otp_app: :holter,
    adapter: Ecto.Adapters.Postgres
end
