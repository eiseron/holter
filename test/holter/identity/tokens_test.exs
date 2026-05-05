defmodule Holter.Identity.TokensTest do
  use Holter.DataCase, async: false

  alias Holter.Identity.Token
  alias Holter.Identity.Tokens

  describe "create_session_token/2" do
    test "returns a plaintext token alongside the persisted row" do
      user = user_fixture()

      {:ok, %Token{type: :session}, plaintext} = Tokens.create_session_token(user)

      assert byte_size(plaintext) > 0
    end

    test "stores the SHA-256 digest, not the plaintext" do
      user = user_fixture()
      {:ok, token, plaintext} = Tokens.create_session_token(user)

      assert token.hashed_value == :crypto.hash(:sha256, plaintext)
    end

    test "captures the supplied context map (UserAgent/IP)" do
      user = user_fixture()
      ctx = %{"user_agent" => "ExUnit", "ip" => "127.0.0.1"}

      {:ok, token, _plaintext} = Tokens.create_session_token(user, ctx)

      assert token.context == ctx
    end
  end

  describe "fetch_user_by_session_token/1" do
    test "returns the user that owns the session" do
      user = user_fixture()
      {:ok, _token, plaintext} = Tokens.create_session_token(user)

      assert Tokens.fetch_user_by_session_token(plaintext).id == user.id
    end

    test "returns nil for an unknown token" do
      assert Tokens.fetch_user_by_session_token("not-a-token") == nil
    end

    test "returns nil for an expired session token" do
      user = user_fixture()
      {:ok, token, plaintext} = Tokens.create_session_token(user)
      past = DateTime.utc_now() |> DateTime.add(-10, :second) |> DateTime.truncate(:second)

      token
      |> Ecto.Changeset.change(expires_at: past)
      |> Repo.update!()

      assert Tokens.fetch_user_by_session_token(plaintext) == nil
    end

    test "extends expires_at when the session is past half its TTL (sliding window)" do
      user = user_fixture()
      {:ok, token, plaintext} = Tokens.create_session_token(user)
      max_age = Application.fetch_env!(:holter, :identity)[:session_max_age_seconds]

      stale_expiry =
        DateTime.utc_now()
        |> DateTime.add(div(max_age, 4), :second)
        |> DateTime.truncate(:second)

      token
      |> Ecto.Changeset.change(expires_at: stale_expiry)
      |> Repo.update!()

      _ = Tokens.fetch_user_by_session_token(plaintext)

      refreshed = Repo.get!(Token, token.id)
      assert DateTime.compare(refreshed.expires_at, stale_expiry) == :gt
    end
  end

  describe "delete_session_token/1" do
    test "removes the row identified by the plaintext digest" do
      user = user_fixture()
      {:ok, token, plaintext} = Tokens.create_session_token(user)

      Tokens.delete_session_token(plaintext)

      refute Repo.get(Token, token.id)
    end
  end

  describe "create_verify_email_token/1 + consume_verify_email_token/1" do
    test "consume returns the matching token row exactly once" do
      user = user_fixture()
      {:ok, _token, plaintext} = Tokens.create_verify_email_token(user)

      assert {:ok, %Token{type: :verify_email}} =
               Tokens.consume_verify_email_token(plaintext)
    end

    test "stamps used_at on the consumed token (anti-replay)" do
      user = user_fixture()
      {:ok, _token, plaintext} = Tokens.create_verify_email_token(user)

      {:ok, %Token{used_at: used_at}} = Tokens.consume_verify_email_token(plaintext)

      refute is_nil(used_at)
    end

    test "rejects a second consumption attempt" do
      user = user_fixture()
      {:ok, _token, plaintext} = Tokens.create_verify_email_token(user)

      {:ok, _} = Tokens.consume_verify_email_token(plaintext)

      assert Tokens.consume_verify_email_token(plaintext) == {:error, :invalid_or_expired}
    end

    test "rejects expired verification tokens" do
      user = user_fixture()
      {:ok, token, plaintext} = Tokens.create_verify_email_token(user)
      past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

      token
      |> Ecto.Changeset.change(expires_at: past)
      |> Repo.update!()

      assert Tokens.consume_verify_email_token(plaintext) == {:error, :invalid_or_expired}
    end
  end

  describe "create_reset_password_token/1" do
    test "persists a row with type :reset_password" do
      user = user_fixture()

      {:ok, %Token{type: type}, _plaintext} = Tokens.create_reset_password_token(user)

      assert type == :reset_password
    end

    test "binds the row to the user that owns the reset" do
      user = user_fixture()

      {:ok, token, _plaintext} = Tokens.create_reset_password_token(user)

      assert token.user_id == user.id
    end

    test "leaves used_at unset so the token is single-use ready" do
      user = user_fixture()

      {:ok, token, _plaintext} = Tokens.create_reset_password_token(user)

      assert is_nil(token.used_at)
    end

    test "expires within the configured TTL window (15 min ± 5s)" do
      user = user_fixture()
      max_age = Application.fetch_env!(:holter, :identity)[:reset_password_token_max_age_seconds]
      now = DateTime.utc_now()

      {:ok, token, _plaintext} = Tokens.create_reset_password_token(user)

      diff = DateTime.diff(token.expires_at, now, :second)
      assert diff in (max_age - 5)..(max_age + 5)
    end

    test "stores the SHA-256 digest of the plaintext" do
      user = user_fixture()

      {:ok, token, plaintext} = Tokens.create_reset_password_token(user)

      assert token.hashed_value == :crypto.hash(:sha256, plaintext)
    end

    test "never persists the plaintext itself" do
      user = user_fixture()

      {:ok, token, plaintext} = Tokens.create_reset_password_token(user)

      refute token.hashed_value == plaintext
    end
  end

  describe "consume_reset_password_token/1" do
    test "returns the matching token row scoped to the user" do
      user = user_fixture()
      {:ok, _token, plaintext} = Tokens.create_reset_password_token(user)
      user_id = user.id

      assert {:ok, %Token{type: :reset_password, user_id: ^user_id}} =
               Tokens.consume_reset_password_token(plaintext)
    end

    test "stamps used_at on the consumed token (anti-replay)" do
      user = user_fixture()
      {:ok, _token, plaintext} = Tokens.create_reset_password_token(user)

      {:ok, %Token{used_at: used_at}} = Tokens.consume_reset_password_token(plaintext)

      assert %DateTime{} = used_at
    end

    test "rejects a second consumption attempt (single-use)" do
      user = user_fixture()
      {:ok, _token, plaintext} = Tokens.create_reset_password_token(user)
      {:ok, _} = Tokens.consume_reset_password_token(plaintext)

      assert Tokens.consume_reset_password_token(plaintext) == {:error, :invalid_or_expired}
    end

    test "rejects expired reset tokens" do
      user = user_fixture()
      {:ok, token, plaintext} = Tokens.create_reset_password_token(user)
      past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

      token
      |> Ecto.Changeset.change(expires_at: past)
      |> Repo.update!()

      assert Tokens.consume_reset_password_token(plaintext) == {:error, :invalid_or_expired}
    end

    test "rejects an unknown plaintext" do
      assert Tokens.consume_reset_password_token("not-a-real-token") ==
               {:error, :invalid_or_expired}
    end

    test "rejects a verify_email token sent to the reset path" do
      user = user_fixture()
      {:ok, _token, plaintext} = Tokens.create_verify_email_token(user)

      assert Tokens.consume_reset_password_token(plaintext) == {:error, :invalid_or_expired}
    end

    test "rejects non-binary input without raising" do
      assert Tokens.consume_reset_password_token(nil) == {:error, :invalid_or_expired}
    end
  end

  describe "delete_user_sessions/1" do
    test "reports the count of deleted session rows for the user" do
      user = user_fixture()
      {:ok, _, _} = Tokens.create_session_token(user)
      {:ok, _, _} = Tokens.create_session_token(user)
      {:ok, _, _} = Tokens.create_session_token(user)

      assert Tokens.delete_user_sessions(user.id) == {:ok, 3}
    end

    test "leaves no session rows behind for the user after deletion" do
      user = user_fixture()
      {:ok, _, _} = Tokens.create_session_token(user)
      {:ok, _, _} = Tokens.create_session_token(user)

      {:ok, _} = Tokens.delete_user_sessions(user.id)

      assert Repo.aggregate(
               from(t in Token, where: t.user_id == ^user.id and t.type == :session),
               :count
             ) == 0
    end

    test "leaves the verify_email token for the same user untouched" do
      user = user_fixture()
      {:ok, _, _} = Tokens.create_session_token(user)
      {:ok, verify_token, _} = Tokens.create_verify_email_token(user)

      {:ok, 1} = Tokens.delete_user_sessions(user.id)

      assert Repo.get(Token, verify_token.id)
    end

    test "leaves the reset_password token for the same user untouched" do
      user = user_fixture()
      {:ok, _, _} = Tokens.create_session_token(user)
      {:ok, reset_token, _} = Tokens.create_reset_password_token(user)

      {:ok, 1} = Tokens.delete_user_sessions(user.id)
      assert Repo.get(Token, reset_token.id)
    end

    test "leaves other users' sessions untouched" do
      target = user_fixture()
      bystander = user_fixture()
      {:ok, _, _} = Tokens.create_session_token(target)
      {:ok, bystander_token, _} = Tokens.create_session_token(bystander)

      {:ok, 1} = Tokens.delete_user_sessions(target.id)

      assert Repo.get(Token, bystander_token.id)
    end

    test "returns {:ok, 0} for a user with no sessions" do
      user = user_fixture()

      assert Tokens.delete_user_sessions(user.id) == {:ok, 0}
    end
  end
end
