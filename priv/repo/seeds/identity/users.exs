defmodule Holter.Seeds.Identity.Users do
  @moduledoc false

  alias Holter.Identity.Memberships
  alias Holter.Identity.Password
  alias Holter.Identity.User
  alias Holter.Repo

  @dev_email "alice@holter.test"
  @dev_password "Holter-Dev-1!"
  @terms_version "v1"

  def create_dev(workspace) do
    pepper = Application.fetch_env!(:holter, :identity)[:pepper]
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    user =
      %User{}
      |> User.registration_changeset(%{
        email: @dev_email,
        hashed_password: Password.hash(@dev_password, pepper),
        terms_accepted_at: now,
        terms_version: @terms_version
      })
      |> Ecto.Changeset.put_change(:email_verified_at, now)
      |> Ecto.Changeset.put_change(:onboarding_status, :active)
      |> Repo.insert!()

    {:ok, _membership} = Memberships.create_default_membership(user, workspace)

    IO.puts("[seeds] Created dev user #{@dev_email} (password: #{@dev_password})")
    user
  end
end
