defmodule Holter.Identity.Tokens do
  @moduledoc """
  Coordinator for the unified `auth_tokens` table. Owns token
  generation (random plaintext), persistence of the SHA-256 digest,
  and atomic single-use consumption. Returns plaintext tokens to
  callers exactly once — never persists them.
  """

  import Ecto.Query

  alias Holter.Identity.Token
  alias Holter.Identity.User
  alias Holter.Repo

  def create_session_token(%User{id: user_id}, context \\ %{}) do
    create_token(user_id, :session, %{context: context, max_age_seconds: session_max_age()})
  end

  def create_verify_email_token(%User{id: user_id}, context \\ %{}) do
    create_token(user_id, :verify_email, %{
      context: context,
      max_age_seconds: verify_email_max_age()
    })
  end

  def fetch_user_by_session_token(plaintext) when is_binary(plaintext) do
    hashed = Token.compute_hash(plaintext)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case fetch_active_token(hashed, :session, now) do
      nil ->
        nil

      %Token{} = token ->
        token = maybe_extend_session(token, now)
        Repo.get(User, token.user_id)
    end
  end

  def fetch_user_by_session_token(_), do: nil

  def delete_session_token(plaintext) when is_binary(plaintext) do
    hashed = Token.compute_hash(plaintext)

    {count, _} =
      Repo.delete_all(from t in Token, where: t.hashed_value == ^hashed and t.type == :session)

    {:ok, count}
  end

  def delete_session_token(_), do: {:ok, 0}

  def consume_verify_email_token(plaintext) when is_binary(plaintext) do
    hashed = Token.compute_hash(plaintext)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      case lock_active_token(hashed, :verify_email, now) do
        nil ->
          Repo.rollback(:invalid_or_expired)

        %Token{} = token ->
          token
          |> Token.consume_changeset(now)
          |> Repo.update!()
      end
    end)
  end

  def consume_verify_email_token(_), do: {:error, :invalid_or_expired}

  defp create_token(user_id, type, %{context: context, max_age_seconds: max_age_seconds}) do
    plaintext = encode_random_token()
    hashed = Token.compute_hash(plaintext)
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires_at = DateTime.add(now, max_age_seconds, :second)

    result =
      Token.insert_changeset(%{
        user_id: user_id,
        type: type,
        hashed_value: hashed,
        context: context,
        expires_at: expires_at
      })
      |> Repo.insert()

    case result do
      {:ok, token} -> {:ok, token, plaintext}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp encode_random_token do
    Token.rand_size()
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp fetch_active_token(hashed, type, now) do
    Repo.one(
      from t in Token,
        where:
          t.hashed_value == ^hashed and t.type == ^type and is_nil(t.used_at) and
            t.expires_at > ^now
    )
  end

  defp lock_active_token(hashed, type, now) do
    Repo.one(
      from t in Token,
        where:
          t.hashed_value == ^hashed and t.type == ^type and is_nil(t.used_at) and
            t.expires_at > ^now,
        lock: "FOR UPDATE"
    )
  end

  defp maybe_extend_session(%Token{expires_at: expires_at} = token, now) do
    max_age = session_max_age()
    seconds_remaining = DateTime.diff(expires_at, now, :second)

    if seconds_remaining < div(max_age, 2) do
      new_expires_at = DateTime.add(now, max_age, :second)

      token
      |> Ecto.Changeset.change(expires_at: new_expires_at)
      |> Repo.update!()
    else
      token
    end
  end

  defp session_max_age, do: identity_config(:session_max_age_seconds)
  defp verify_email_max_age, do: identity_config(:verify_email_token_max_age_seconds)

  defp identity_config(key) do
    Application.fetch_env!(:holter, :identity) |> Keyword.fetch!(key)
  end
end
