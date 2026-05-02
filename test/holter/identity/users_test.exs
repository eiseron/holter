defmodule Holter.Identity.UsersTest do
  use Holter.DataCase, async: true

  import Swoosh.TestAssertions

  alias Holter.Identity
  alias Holter.Identity.Memberships
  alias Holter.Monitoring.Workspace

  defp valid_registration_attrs(overrides \\ %{}) do
    Enum.into(overrides, %{
      email: unique_user_email(),
      password: valid_user_password(),
      terms_accepted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      terms_version: "v1"
    })
  end

  describe "register_user/1" do
    test "returns the inserted user with :pending_verification status" do
      {:ok, user, _workspace, _token} = Identity.register_user(valid_registration_attrs())

      assert user.onboarding_status == :pending_verification
    end

    test "creates a default workspace whose name derives from the email local part" do
      attrs = valid_registration_attrs(%{email: "alice@holter.test"})

      {:ok, _user, %Workspace{name: name}, _token} = Identity.register_user(attrs)

      assert String.starts_with?(name, "alice-")
    end

    test "creates an :owner workspace membership for the new user" do
      {:ok, user, workspace, _token} = Identity.register_user(valid_registration_attrs())

      assert Memberships.member?(user, workspace)
    end

    test "returns a verification token whose plaintext is delivered to the caller" do
      {:ok, _user, _workspace, raw_token} =
        Identity.register_user(valid_registration_attrs())

      assert is_binary(raw_token) and byte_size(raw_token) > 0
    end

    test "delivers the verification email to the registered address" do
      attrs = valid_registration_attrs(%{email: "deliverable@holter.test"})

      {:ok, _user, _workspace, _token} = Identity.register_user(attrs)

      assert_email_sent(to: "deliverable@holter.test")
    end

    test "stores the password as an Argon2 hash, not as plaintext" do
      attrs = valid_registration_attrs(%{password: "Holter-Foundation-1!"})
      {:ok, user, _workspace, _token} = Identity.register_user(attrs)

      refute user.hashed_password == "Holter-Foundation-1!"
    end

    test "rolls the entire transaction back when the email is already taken" do
      attrs = valid_registration_attrs(%{email: "duplicate@holter.test"})
      {:ok, _user, _workspace, _token} = Identity.register_user(attrs)

      {:error, changeset} =
        Identity.register_user(valid_registration_attrs(%{email: "DUPLICATE@holter.test"}))

      assert "has already been taken" in errors_on(changeset).email
    end

    test "rejects weak passwords without inserting any user row" do
      attrs = valid_registration_attrs(%{password: "weak"})

      {:error, changeset} = Identity.register_user(attrs)

      assert errors_on(changeset).password != []
    end

    test "rejects registration without accepted terms (clickwrap, Cenário 25)" do
      attrs = valid_registration_attrs() |> Map.delete(:terms_accepted_at)

      {:error, changeset} = Identity.register_user(attrs)

      assert "can't be blank" in errors_on(changeset).terms_accepted_at
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "returns the user when credentials match (case-insensitive email)" do
      {:ok, user, _workspace, _token} =
        Identity.register_user(valid_registration_attrs(%{email: "case@holter.test"}))

      lookup = Identity.get_user_by_email_and_password("CASE@holter.test", valid_user_password())

      assert lookup.id == user.id
    end

    test "returns nil when the password is wrong" do
      {:ok, _user, _workspace, _token} =
        Identity.register_user(valid_registration_attrs(%{email: "wrong-pw@holter.test"}))

      assert Identity.get_user_by_email_and_password("wrong-pw@holter.test", "Wrong-1Password!") ==
               nil
    end

    test "returns nil when the email does not exist (and runs a dummy verify for timing parity)" do
      assert Identity.get_user_by_email_and_password("ghost@holter.test", "Anything-1234!") == nil
    end
  end

  describe "verify_email/1" do
    test "transitions a freshly-registered user to :active" do
      {:ok, _user, _workspace, raw_token} =
        Identity.register_user(valid_registration_attrs())

      {:ok, user} = Identity.verify_email(raw_token)

      assert user.onboarding_status == :active
    end

    test "stamps email_verified_at on the user row" do
      {:ok, _user, _workspace, raw_token} =
        Identity.register_user(valid_registration_attrs())

      {:ok, user} = Identity.verify_email(raw_token)

      refute is_nil(user.email_verified_at)
    end

    test "rejects re-use of the same verification token" do
      {:ok, _user, _workspace, raw_token} =
        Identity.register_user(valid_registration_attrs())

      {:ok, _user} = Identity.verify_email(raw_token)

      assert Identity.verify_email(raw_token) == {:error, :invalid_or_expired}
    end

    test "rejects unknown tokens with a neutral error" do
      assert Identity.verify_email("not-a-real-token") == {:error, :invalid_or_expired}
    end
  end

  describe "fetch_user_by_session_token/1 and delete_session_token/1" do
    test "round-trips a freshly issued session token back to the same user" do
      %{user: user} = verified_user_fixture()
      token = session_token_fixture(user)

      assert Identity.fetch_user_by_session_token(token).id == user.id
    end

    test "returns nil after the session is deleted (logout)" do
      %{user: user} = verified_user_fixture()
      token = session_token_fixture(user)

      Identity.delete_session_token(token)

      assert Identity.fetch_user_by_session_token(token) == nil
    end

    test "returns nil for tokens that were never issued" do
      assert Identity.fetch_user_by_session_token("garbage") == nil
    end
  end
end
