defmodule HolterWeb.Api.DeliveryLogControllerTest do
  use HolterWeb.ConnCase, async: true
  use Oban.Testing, repo: Holter.Repo

  import OpenApiSpex.TestAssertions

  alias Holter.Delivery
  alias Holter.Delivery.Workers.WebhookDispatcher
  alias HolterWeb.Api.ApiSpec

  setup %{conn: conn} do
    workspace = workspace_fixture()
    api_spec = ApiSpec.spec()

    {:ok, channel} =
      Delivery.create_channel(%{
        workspace_id: workspace.id,
        name: "Test Webhook",
        type: :webhook,
        target: "https://example.com/hook"
      })

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")

    {:ok, conn: conn, channel: channel, api_spec: api_spec}
  end

  defp job_fixture(channel_id, state \\ "completed") do
    args = %{
      "channel_id" => channel_id,
      "event" => "down",
      "monitor_id" => Ecto.UUID.generate(),
      "incident_id" => Ecto.UUID.generate()
    }

    {:ok, job} = WebhookDispatcher.new(args) |> Holter.Repo.insert()

    Holter.Repo.update!(
      Ecto.Changeset.change(job, state: state, attempted_at: DateTime.utc_now())
    )
  end

  describe "GET /api/v1/notification_channels/:id/delivery_logs" do
    test "returns paginated delivery logs matching DeliveryLogList schema", %{
      conn: conn,
      channel: channel,
      api_spec: spec
    } do
      job_fixture(channel.id)

      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}/delivery_logs")
      body = json_response(conn, 200)

      assert %{"data" => [_], "meta" => %{"page" => 1}} = body
      assert_schema(body, "DeliveryLogList", spec)
    end

    test "returns empty list when channel has no logs", %{conn: conn, channel: channel} do
      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}/delivery_logs")
      assert %{"data" => [], "meta" => %{"total_pages" => 1}} = json_response(conn, 200)
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn =
        get(
          conn,
          ~p"/api/v1/notification_channels/00000000-0000-0000-0000-000000000000/delivery_logs"
        )

      assert json_response(conn, 404)
    end

    test "each log entry matches DeliveryLog schema", %{
      conn: conn,
      channel: channel,
      api_spec: spec
    } do
      job_fixture(channel.id, "completed")
      job_fixture(channel.id, "discarded")

      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}/delivery_logs")
      body = json_response(conn, 200)

      assert length(body["data"]) == 2
      assert_schema(body, "DeliveryLogList", spec)
    end

    test "filters by status=success returns only completed jobs", %{
      conn: conn,
      channel: channel
    } do
      job_fixture(channel.id, "completed")
      job_fixture(channel.id, "discarded")

      conn =
        get(conn, ~p"/api/v1/notification_channels/#{channel.id}/delivery_logs", %{
          status: "success"
        })

      body = json_response(conn, 200)

      assert %{"data" => [log]} = body
      assert log["status"] == "success"
    end

    test "filters by status=failed returns only non-completed jobs", %{
      conn: conn,
      channel: channel
    } do
      job_fixture(channel.id, "completed")
      job_fixture(channel.id, "discarded")

      conn =
        get(conn, ~p"/api/v1/notification_channels/#{channel.id}/delivery_logs", %{
          status: "failed"
        })

      body = json_response(conn, 200)

      assert %{"data" => [log]} = body
      assert log["status"] == "failed"
    end

    test "logs from other channels are not returned", %{conn: conn, channel: channel} do
      other_workspace = workspace_fixture()

      {:ok, other_channel} =
        Delivery.create_channel(%{
          workspace_id: other_workspace.id,
          name: "Other",
          type: :webhook,
          target: "https://other.example.com/hook"
        })

      job_fixture(other_channel.id)

      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}/delivery_logs")
      assert %{"data" => []} = json_response(conn, 200)
    end
  end
end
