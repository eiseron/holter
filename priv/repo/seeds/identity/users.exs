defmodule Holter.Seeds.Identity.Users do
  @moduledoc false

  alias Holter.Identity.Memberships
  alias Holter.Identity.Models.User
  alias Holter.Identity.Password
  alias Holter.Repo

  @dev_email "alice@holter.test"
  @extra_email "bob@holter.test"
  @dev_password "Holter-Dev-1!"
  @terms_version "v1"

  def create_dev(workspaces) do
    user = create_user(@dev_email, workspaces)
    IO.puts("[seeds] Created dev user #{@dev_email} (password: #{@dev_password})")
    user
  end

  def create_extra(workspaces) do
    user = create_user(@extra_email, workspaces)
    IO.puts("[seeds] Created extra user #{@extra_email} (password: #{@dev_password})")
    user
  end

  defp create_user(email, workspaces) do
    pepper = Application.fetch_env!(:holter, :identity)[:pepper]
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    user =
      %User{}
      |> User.registration_changeset(%{
        email: email,
        hashed_password: Password.hash(@dev_password, pepper),
        terms_accepted_at: now,
        terms_version: @terms_version
      })
      |> Ecto.Changeset.put_change(:email_verified_at, now)
      |> Ecto.Changeset.put_change(:onboarding_status, :active)
      |> Repo.insert!()

    Enum.each(workspaces, fn workspace ->
      {:ok, _membership} = Memberships.create_default_membership(user, workspace)
    end)

    user
  end
end
