defmodule Holter.Identity.PasswordsTest do
  use Holter.DataCase, async: false

  import Swoosh.TestAssertions

  alias Eiseron.Identity.Password
  alias Holter.Identity
  alias Holter.Identity.Models.Token
  alias Holter.Identity.Models.User
  alias Holter.Identity.Tokens

  defp pepper do
    Application.fetch_env!(:holter, :identity)[:pepper]
  end

  defp reload(%User{id: id}), do: Repo.get!(User, id)

  defp drain_mailbox do
    receive do
      {:email, _} -> drain_mailbox()
    after
      0 -> :ok
    end
  end

  describe "request_password_reset/1 — known email (happy path)" do
    test "creates exactly one :reset_password token for the user" do
      %{user: user} = verified_user_fixture()
      drain_mailbox()

      :ok = Identity.request_password_reset(user.email)

      assert Repo.aggregate(
               from(t in Token,
                 where: t.user_id == ^user.id and t.type == :reset_password
               ),
               :count
             ) == 1
    end

    test "delivers an email addressed to the user" do
      %{user: user} = verified_user_fixture()
      drain_mailbox()

      :ok = Identity.request_password_reset(user.email)

      assert_email_sent(to: user.email)
    end

    test "the delivered email carries a clickable reset URL in the body" do
      %{user: user} = verified_user_fixture()
      drain_mailbox()

      :ok = Identity.request_password_reset(user.email)

      assert_email_sent(fn email ->
        assert email.text_body =~ "/identity/reset-password/"
      end)
    end

    test "matches the user via case-insensitive email lookup (EmailNormalizer)" do
      %{user: user} = verified_user_fixture()
      drain_mailbox()
      mixed_case = user.email |> String.upcase()

      :ok = Identity.request_password_reset(mixed_case)

      assert Repo.aggregate(
               from(t in Token, where: t.user_id == ^user.id and t.type == :reset_password),
               :count
             ) == 1
    end
  end

  describe "request_password_reset/1 — unknown or invalid input (no enumeration leak)" do
    test "returns :ok without persisting any token for an unknown email" do
      :ok = Identity.request_password_reset("ghost-#{System.unique_integer()}@holter.test")

      assert Repo.aggregate(
               from(t in Token, where: t.type == :reset_password),
               :count
             ) == 0
    end

    test "does not deliver any email for an unknown address" do
      :ok = Identity.request_password_reset("nobody-#{System.unique_integer()}@holter.test")

      refute_email_sent()
    end

    test "tolerates nil input without raising" do
      assert Identity.request_password_reset(nil) == :ok
    end

    test "tolerates non-string input without raising" do
      assert Identity.request_password_reset(:atom) == :ok
    end
  end

  describe "reset_password/2 — happy path" do
    setup do
      %{user: user} = verified_user_fixture()
      {:ok, _token, plaintext} = Tokens.create_reset_password_token(user)
      drain_mailbox()
      {:ok, user: user, plaintext: plaintext}
    end

    test "replaces the password hash with one that verifies the new password",
         %{user: user, plaintext: plaintext} do
      original_hash = user.hashed_password
      new_password = "Br4nd-NewP4ssword!"

      {:ok, _updated} = Identity.reset_password(plaintext, new_password)

      reloaded = reload(user)
      refute reloaded.hashed_password == original_hash
      assert Password.verify(new_password, reloaded.hashed_password, pepper())
    end

    test "revokes every active session for the user (Soberania da Sessão)",
         %{user: user, plaintext: plaintext} do
      session_token_fixture(user)
      session_token_fixture(user)
      session_token_fixture(user)

      {:ok, _} = Identity.reset_password(plaintext, "Br4nd-NewP4ssword!")

      assert Repo.aggregate(
               from(t in Token, where: t.user_id == ^user.id and t.type == :session),
               :count
             ) == 0
    end

    test "leaves other users' sessions untouched", %{user: user, plaintext: plaintext} do
      bystander = user_fixture()
      bystander_session = session_token_fixture(bystander)

      {:ok, _} = Identity.reset_password(plaintext, "Br4nd-NewP4ssword!")

      assert Tokens.fetch_user_by_session_token(bystander_session).id == bystander.id
      _ = user
    end

    test "delivers the change-alert email to the user", %{user: user, plaintext: plaintext} do
      {:ok, _} = Identity.reset_password(plaintext, "Br4nd-NewP4ssword!")

      assert_email_sent(to: user.email, subject: "Your password has been changed")
    end

    test "consumes the reset token (single-use enforced)", %{plaintext: plaintext} do
      {:ok, _} = Identity.reset_password(plaintext, "Br4nd-NewP4ssword!")

      assert Identity.reset_password(plaintext, "An0therP4ssword!") ==
               {:error, :invalid_or_expired}
    end
  end

  describe "reset_password/2 — invalid token" do
    test "returns :invalid_or_expired for an unknown plaintext" do
      assert Identity.reset_password("not-a-real-token", "Br4nd-NewP4ssword!") ==
               {:error, :invalid_or_expired}
    end

    test "returns :invalid_or_expired for an expired token" do
      %{user: user} = verified_user_fixture()
      {:ok, token, plaintext} = Tokens.create_reset_password_token(user)
      past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

      token
      |> Ecto.Changeset.change(expires_at: past)
      |> Repo.update!()

      assert Identity.reset_password(plaintext, "Br4nd-NewP4ssword!") ==
               {:error, :invalid_or_expired}
    end

    test "leaves the password unchanged when the token is expired" do
      %{user: user} = verified_user_fixture()
      {:ok, token, plaintext} = Tokens.create_reset_password_token(user)
      original_hash = reload(user).hashed_password
      past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

      token
      |> Ecto.Changeset.change(expires_at: past)
      |> Repo.update!()

      {:error, :invalid_or_expired} = Identity.reset_password(plaintext, "Br4nd-NewP4ssword!")

      assert reload(user).hashed_password == original_hash
    end

    test "leaves active sessions untouched when the token is expired" do
      %{user: user} = verified_user_fixture()
      session_plaintext = session_token_fixture(user)
      {:ok, token, plaintext} = Tokens.create_reset_password_token(user)
      past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

      token
      |> Ecto.Changeset.change(expires_at: past)
      |> Repo.update!()

      {:error, :invalid_or_expired} = Identity.reset_password(plaintext, "Br4nd-NewP4ssword!")

      assert Tokens.fetch_user_by_session_token(session_plaintext).id == user.id
    end

    test "does not deliver an alert email when the token is expired" do
      %{user: user} = verified_user_fixture()
      {:ok, token, plaintext} = Tokens.create_reset_password_token(user)
      past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

      token
      |> Ecto.Changeset.change(expires_at: past)
      |> Repo.update!()

      drain_mailbox()

      {:error, :invalid_or_expired} = Identity.reset_password(plaintext, "Br4nd-NewP4ssword!")

      refute_email_sent()
    end

    test "rejects a second consumption with :invalid_or_expired" do
      %{user: user} = verified_user_fixture()
      {:ok, _token, plaintext} = Tokens.create_reset_password_token(user)
      {:ok, _} = Identity.reset_password(plaintext, "First-One-P4ssword!")

      assert Identity.reset_password(plaintext, "Second-One-P4ssword!") ==
               {:error, :invalid_or_expired}
    end

    test "the second consumption attempt does not change the password" do
      %{user: user} = verified_user_fixture()
      {:ok, _token, plaintext} = Tokens.create_reset_password_token(user)
      {:ok, _} = Identity.reset_password(plaintext, "First-One-P4ssword!")
      hash_after_first = reload(user).hashed_password

      {:error, :invalid_or_expired} = Identity.reset_password(plaintext, "Second-One-P4ssword!")

      assert reload(user).hashed_password == hash_after_first
    end

    test "rejects non-binary token without raising" do
      assert Identity.reset_password(nil, "Br4nd-NewP4ssword!") ==
               {:error, :invalid_or_expired}
    end
  end

  describe "reset_password/2 — weak password" do
    setup do
      %{user: user} = verified_user_fixture()
      {:ok, _token, plaintext} = Tokens.create_reset_password_token(user)
      drain_mailbox()
      {:ok, user: user, plaintext: plaintext}
    end

    test "returns an Ecto.Changeset error keyed on :password",
         %{plaintext: plaintext} do
      assert {:error, %Ecto.Changeset{} = cs} = Identity.reset_password(plaintext, "short")

      assert Map.has_key?(errors_on(cs), :password)
    end

    test "leaves the password hash untouched", %{user: user, plaintext: plaintext} do
      original_hash = reload(user).hashed_password

      {:error, %Ecto.Changeset{}} = Identity.reset_password(plaintext, "short")

      assert reload(user).hashed_password == original_hash
    end

    test "leaves active sessions intact", %{user: user, plaintext: plaintext} do
      session_plaintext = session_token_fixture(user)

      {:error, %Ecto.Changeset{}} = Identity.reset_password(plaintext, "short")

      assert Tokens.fetch_user_by_session_token(session_plaintext).id == user.id
    end

    test "does not deliver the change-alert email", %{plaintext: plaintext} do
      {:error, %Ecto.Changeset{}} = Identity.reset_password(plaintext, "short")

      refute_email_sent()
    end

    test "does not consume the reset token (user can retry with a strong password)",
         %{user: user, plaintext: plaintext} do
      {:error, %Ecto.Changeset{}} = Identity.reset_password(plaintext, "short")
      {:ok, _} = Identity.reset_password(plaintext, "Br4nd-NewP4ssword!")

      assert Password.verify("Br4nd-NewP4ssword!", reload(user).hashed_password, pepper())
    end
  end
end
