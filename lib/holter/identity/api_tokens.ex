defmodule Holter.Identity.ApiTokens do
  @moduledoc """
  Coordinator for the `api_tokens` table — workspace-scoped bearer
  tokens used by the public API. Owns plaintext generation, digest
  persistence, lookup-by-plaintext (via the SECURITY DEFINER bootstrap
  function `auth_lookup_api_token`), revocation, and last-used touch.

  Plaintext is returned to callers exactly once at creation; only the
  SHA-256 digest is persisted.
  """

  import Ecto.Query

  alias Holter.Identity.ApiToken
  alias Holter.Identity.Memberships
  alias Holter.Identity.User
  alias Holter.Monitoring.Workspace
  alias Holter.Repo
  alias Holter.Repo.Tenant

  @doc """
  Creates an API token for `user` in `workspace`. Asserts the user holds
  the `:owner` role on the workspace; non-owners get `{:error, :forbidden}`.

  Returns `{:ok, token, plaintext}` on success — plaintext only here.
  """
  def create_token(%User{} = user, %Workspace{} = workspace, attrs) do
    if Memberships.owner?(user, workspace) do
      do_create_token(user, workspace, attrs)
    else
      {:error, :forbidden}
    end
  end

  @doc """
  Lists all tokens for the given workspace, newest first.
  """
  def list_tokens_for_workspace(%Workspace{id: workspace_id}) do
    Tenant.with_workspace!(workspace_id, fn ->
      Repo.all(
        from t in ApiToken,
          where: t.workspace_id == ^workspace_id,
          order_by: [desc: t.inserted_at]
      )
    end)
  end

  @doc """
  Looks up an active token by plaintext via the SECURITY DEFINER
  bootstrap function. Runs without tenant context — this is the entry
  point that *resolves* the workspace; nothing earlier in the request
  knows it. Returns `nil` when the token doesn't exist, is revoked, or
  has expired.
  """
  def fetch_active_token_by_plaintext(plaintext) when is_binary(plaintext) do
    hashed = ApiToken.compute_hash(plaintext)

    case Repo.query!(
           "SELECT id, user_id, workspace_id, scopes, expires_at, last_used_at, revoked_at, inserted_at, name FROM auth_lookup_api_token($1)",
           [hashed]
         ) do
      %{rows: []} ->
        nil

      %{rows: [row]} ->
        hydrate_token(row)
    end
  end

  def fetch_active_token_by_plaintext(_), do: nil

  @doc """
  Marks a token as revoked. Idempotent — re-revoking a revoked token
  is a no-op.
  """
  def revoke_token(%ApiToken{revoked_at: nil} = token) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Tenant.with_workspace!(token.workspace_id, fn ->
      token
      |> ApiToken.revoke_changeset(now)
      |> Repo.update()
    end)
  end

  def revoke_token(%ApiToken{} = token), do: {:ok, token}

  @doc """
  Best-effort update of `last_used_at` for an authenticated request.
  Uses `update_all` so the request path is never blocked by races with
  a concurrent revoke.
  """
  def touch_last_used(%ApiToken{id: id, workspace_id: workspace_id}, %DateTime{} = now) do
    Tenant.with_workspace!(workspace_id, fn ->
      Repo.update_all(
        from(t in ApiToken, where: t.id == ^id),
        set: [last_used_at: DateTime.truncate(now, :second)]
      )
    end)

    :ok
  end

  defp do_create_token(user, workspace, attrs) do
    plaintext = random_plaintext()
    hashed = ApiToken.compute_hash(plaintext)

    changeset =
      attrs
      |> normalize_attrs()
      |> Map.put(:user_id, user.id)
      |> Map.put(:workspace_id, workspace.id)
      |> Map.put(:hashed_value, hashed)
      |> ApiToken.insert_changeset()

    result =
      Tenant.with_workspace!(workspace.id, fn ->
        Repo.insert(changeset)
      end)

    case result do
      {:ok, token} -> {:ok, token, plaintext}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp random_plaintext do
    random =
      ApiToken.rand_size()
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64(padding: false)

    ApiToken.plaintext_prefix() <> random
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    Enum.into(attrs, %{}, fn
      {k, v} when is_atom(k) -> {k, v}
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
    end)
  end

  defp hydrate_token([
         id,
         user_id,
         workspace_id,
         scopes,
         expires_at,
         last_used_at,
         revoked_at,
         inserted_at,
         name
       ]) do
    %ApiToken{
      id: cast_uuid(id),
      user_id: cast_uuid(user_id),
      workspace_id: cast_uuid(workspace_id),
      scopes: scopes || [],
      expires_at: cast_datetime(expires_at),
      last_used_at: cast_datetime(last_used_at),
      revoked_at: cast_datetime(revoked_at),
      inserted_at: cast_datetime(inserted_at),
      name: name
    }
  end

  defp cast_uuid(nil), do: nil
  defp cast_uuid(<<_::128>> = bin), do: Ecto.UUID.cast!(bin)
  defp cast_uuid(str) when is_binary(str), do: str

  defp cast_datetime(nil), do: nil
  defp cast_datetime(%DateTime{} = dt), do: DateTime.truncate(dt, :second)

  defp cast_datetime(%NaiveDateTime{} = ndt) do
    ndt |> DateTime.from_naive!("Etc/UTC") |> DateTime.truncate(:second)
  end
end
