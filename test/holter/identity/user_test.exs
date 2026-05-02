defmodule Holter.Identity.UserTest do
  use Holter.DataCase, async: true

  alias Holter.Identity.User

  describe "registration_changeset/2" do
    test "is valid with email, hashed_password, and accepted terms" do
      changeset = User.registration_changeset(%User{}, valid_user_attrs())

      assert changeset.valid?
    end

    test "downcases and trims the email so case variants collide" do
      attrs = valid_user_attrs(%{email: "  Mixed.Case@Holter.Test  "})

      changeset = User.registration_changeset(%User{}, attrs)

      assert get_change(changeset, :email) == "mixed.case@holter.test"
    end

    test "requires acceptance of terms (clickwrap, Cenário 25)" do
      attrs = valid_user_attrs() |> Map.delete(:terms_accepted_at)

      changeset = User.registration_changeset(%User{}, attrs)

      assert "can't be blank" in errors_on(changeset).terms_accepted_at
    end

    test "rejects malformed email addresses" do
      attrs = valid_user_attrs(%{email: "not-an-email"})

      changeset = User.registration_changeset(%User{}, attrs)

      assert "must be a valid email address" in errors_on(changeset).email
    end

    test "enforces email uniqueness across case variants" do
      first = valid_user_attrs(%{email: "shared@holter.test"})
      _ = user_fixture(first)

      duplicate = valid_user_attrs(%{email: "SHARED@holter.test"})

      {:error, changeset} =
        %User{}
        |> User.registration_changeset(duplicate)
        |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).email
    end

    test "defaults onboarding_status to :pending_verification" do
      user = user_fixture()

      assert user.onboarding_status == :pending_verification
    end

    test "redacts hashed_password from inspect output" do
      user = user_fixture()

      refute inspect(user) =~ user.hashed_password
    end
  end

  describe "email_verification_changeset/2" do
    test "stamps email_verified_at with the supplied moment" do
      user = user_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, verified} =
        user
        |> User.email_verification_changeset(now)
        |> Repo.update()

      assert verified.email_verified_at == now
    end

    test "transitions :pending_verification to :active" do
      user = user_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, verified} =
        user
        |> User.email_verification_changeset(now)
        |> Repo.update()

      assert verified.onboarding_status == :active
    end

    test "leaves a :banned account banned" do
      user =
        user_fixture()
        |> Ecto.Changeset.change(onboarding_status: :banned)
        |> Repo.update!()

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, verified} =
        user
        |> User.email_verification_changeset(now)
        |> Repo.update()

      assert verified.onboarding_status == :banned
    end
  end
end
