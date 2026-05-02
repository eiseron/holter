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
end
