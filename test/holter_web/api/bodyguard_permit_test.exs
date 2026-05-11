defmodule HolterWeb.Api.BodyguardPermitTest do
  @moduledoc """
  Cross-controller smoke tests that verify the boundary `Bodyguard.permit`
  calls actually translate to HTTP 403 when the actor lacks the required
  role. One representative case per protected mutation surface.
  """
  use HolterWeb.ConnCase

  alias Ecto.Changeset
  alias Holter.Delivery.{EmailChannels, WebhookChannels}
  alias Holter.Identity.Memberships
  alias Holter.Repo
  alias Holter.Repo.Tenant

  setup %{conn: conn, current_user: user, current_workspace: workspace} do
    {:ok, conn: authed(conn, user, workspace), workspace: workspace, user: user}
  end

  describe "DELETE /monitors/:id" do
    test "returns 403 when the actor is a plain member", ctx do
      monitor = monitor_fixture(workspace_id: ctx.workspace.id, interval_seconds: 600)
      demote_to_member(ctx.user, ctx.workspace)

      conn = delete(ctx.conn, ~p"/api/v1/monitors/#{monitor.id}")

      assert json_response(conn, 403)
    end
  end

  describe "DELETE /email_channels/:id" do
    test "returns 403 when the actor is a plain member", ctx do
      {:ok, channel} =
        EmailChannels.create(%{workspace_id: ctx.workspace.id, name: "alerts"})

      demote_to_member(ctx.user, ctx.workspace)

      conn = delete(ctx.conn, ~p"/api/v1/email_channels/#{channel.id}")

      assert json_response(conn, 403)
    end
  end

  describe "DELETE /webhook_channels/:id" do
    test "returns 403 when the actor is a plain member", ctx do
      {:ok, channel} =
        WebhookChannels.create(%{
          workspace_id: ctx.workspace.id,
          name: "alerts",
          url: "https://example.com/hook"
        })

      demote_to_member(ctx.user, ctx.workspace)

      conn = delete(ctx.conn, ~p"/api/v1/webhook_channels/#{channel.id}")

      assert json_response(conn, 403)
    end
  end

  defp authed(conn, user, workspace) do
    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("content-type", "application/json")
    |> authed_api_conn({user, workspace})
  end

  defp demote_to_member(user, workspace) do
    membership = Memberships.get_membership(user, workspace)

    Tenant.with_user!(user, fn ->
      membership
      |> Changeset.change(role: :member)
      |> Repo.update!()
    end)
  end
end
