defmodule HolterWeb.Plugs.FetchApiBearerPlugTest do
  use HolterWeb.ConnCase, async: false

  alias Ecto.Changeset
  alias Holter.Identity.ApiTokens
  alias Holter.Identity.Models.ApiToken
  alias Holter.Repo
  alias Holter.Repo.Tenant
  alias HolterWeb.Plugs.FetchApiBearerPlug

  describe "missing or malformed credentials" do
    test "401 when no Authorization header" do
      conn = build_conn() |> FetchApiBearerPlug.call([])

      assert conn.status == 401
    end

    test "401 when scheme is not Bearer" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Basic dXNlcjpwYXNz")
        |> FetchApiBearerPlug.call([])

      assert conn.status == 401
    end

    test "401 when Bearer token is empty" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer ")
        |> FetchApiBearerPlug.call([])

      assert conn.status == 401
    end

    test "401 body is `unauthorized` (same for every 401 path)" do
      conn = build_conn() |> FetchApiBearerPlug.call([])

      assert conn.resp_body == ~s({"error":"unauthorized"})
    end
  end

  describe "unknown / revoked / expired tokens" do
    setup :owned_workspace

    test "401 when the digest doesn't match any row", %{conn: conn} do
      conn = conn |> bearer("hk_unknown_plaintext") |> FetchApiBearerPlug.call([])

      assert conn.status == 401
    end

    test "401 when the matching token is revoked", %{user: user, workspace: workspace, conn: conn} do
      {token, plaintext} = api_token_fixture(user, workspace)
      {:ok, _} = ApiTokens.revoke_token(token)

      conn = conn |> bearer(plaintext) |> FetchApiBearerPlug.call([])

      assert conn.status == 401
    end

    test "401 when the matching token has expired",
         %{user: user, workspace: workspace, conn: conn} do
      {token, plaintext} = api_token_fixture(user, workspace)
      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      Tenant.with_workspace!(workspace.id, fn ->
        token |> Changeset.change(expires_at: past) |> Repo.update!()
      end)

      conn = conn |> bearer(plaintext) |> FetchApiBearerPlug.call([])

      assert conn.status == 401
    end
  end

  describe "successful authentication" do
    setup :owned_workspace

    test "assigns current_api_token", %{user: user, workspace: workspace, conn: conn} do
      {token, plaintext} = api_token_fixture(user, workspace)

      conn = conn |> bearer(plaintext) |> FetchApiBearerPlug.call([])

      assert conn.assigns.current_api_token.id == token.id
    end

    test "assigns current_user", %{user: user, workspace: workspace, conn: conn} do
      {_token, plaintext} = api_token_fixture(user, workspace)

      conn = conn |> bearer(plaintext) |> FetchApiBearerPlug.call([])

      assert conn.assigns.current_user.id == user.id
    end

    test "assigns current_workspace", %{user: user, workspace: workspace, conn: conn} do
      {_token, plaintext} = api_token_fixture(user, workspace)

      conn = conn |> bearer(plaintext) |> FetchApiBearerPlug.call([])

      assert conn.assigns.current_workspace.id == workspace.id
    end

    test "exposes the token's scopes via :token_scopes",
         %{user: user, workspace: workspace, conn: conn} do
      {_token, plaintext} =
        api_token_fixture(user, workspace, scopes: ["read:monitors", "write:monitors"])

      conn = conn |> bearer(plaintext) |> FetchApiBearerPlug.call([])

      assert Enum.sort(conn.assigns.token_scopes) == ["read:monitors", "write:monitors"]
    end

    test "leaves the response not-yet-sent so downstream plugs can run",
         %{user: user, workspace: workspace, conn: conn} do
      {_token, plaintext} = api_token_fixture(user, workspace)

      conn = conn |> bearer(plaintext) |> FetchApiBearerPlug.call([])

      assert conn.state == :unset
    end

    test "touches last_used_at on the matched token",
         %{user: user, workspace: workspace, conn: conn} do
      {token, plaintext} = api_token_fixture(user, workspace)

      conn |> bearer(plaintext) |> FetchApiBearerPlug.call([])

      reloaded =
        Tenant.with_workspace!(workspace.id, fn -> Repo.get!(ApiToken, token.id) end)

      assert %DateTime{} = reloaded.last_used_at
    end
  end

  defp owned_workspace(%{conn: conn}) do
    user = user_fixture()
    workspace = workspace_fixture(owner: user)
    {:ok, %{conn: conn, user: user, workspace: workspace}}
  end

  defp bearer(conn, plaintext), do: put_req_header(conn, "authorization", "Bearer " <> plaintext)
end
