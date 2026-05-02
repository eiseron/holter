defmodule Holter.IdentityFixtures do
  @moduledoc """
  Test helpers for building entities in the `Holter.Identity` domain.
  """

  alias Holter.Identity
  alias Holter.Identity.Tokens
  alias Holter.Identity.User
  alias Holter.Repo

  def unique_user_email do
    "user-#{System.unique_integer([:positive])}@holter.test"
  end

  def valid_user_password, do: "Holter-Foundation-1!"

  def valid_user_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      hashed_password: "stub-hash-not-a-real-argon2-hash",
      terms_accepted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      terms_version: "v1"
    })
  end

  def user_fixture(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(valid_user_attrs(attrs))
    |> Repo.insert!()
  end

  def register_user_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        email: unique_user_email(),
        password: valid_user_password(),
        terms_accepted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        terms_version: "v1"
      })

    {:ok, user, workspace, raw_verify_token} = Identity.register_user(attrs)
    %{user: user, workspace: workspace, raw_verify_token: raw_verify_token}
  end

  def verified_user_fixture(attrs \\ %{}) do
    %{workspace: workspace, raw_verify_token: raw_token} = register_user_fixture(attrs)
    {:ok, user} = Identity.verify_email(raw_token)
    %{user: user, workspace: workspace}
  end

  def session_token_fixture(%User{} = user) do
    {:ok, _token, plaintext} = Tokens.create_session_token(user)
    plaintext
  end
end
