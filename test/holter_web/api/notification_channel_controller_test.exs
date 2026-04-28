defmodule HolterWeb.Api.NotificationChannelControllerTest do
  use HolterWeb.ConnCase
  use Oban.Testing, repo: Holter.Repo

  import OpenApiSpex.TestAssertions
  import Swoosh.TestAssertions

  alias Holter.Delivery
  alias HolterWeb.Api.ApiSpec

  setup %{conn: conn} do
    workspace = workspace_fixture(%{name: "Test Workspace", slug: "test-workspace"})
    api_spec = ApiSpec.spec()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")

    {:ok, conn: conn, workspace: workspace, api_spec: api_spec}
  end

  defp json_post(conn, path, body), do: post(conn, path, Jason.encode!(body))
  defp json_put(conn, path, body), do: put(conn, path, Jason.encode!(body))

  defp channel_fixture(workspace_id, attrs \\ %{}) do
    {:ok, channel} =
      Delivery.create_channel(
        Map.merge(
          %{
            workspace_id: workspace_id,
            name: "Test Webhook",
            type: :webhook,
            target: "https://example.com/hook"
          },
          attrs
        )
      )

    channel
  end

  defp verified_email_channel_fixture(workspace_id, attrs \\ %{}) do
    channel =
      channel_fixture(
        workspace_id,
        Map.merge(%{name: "Email", type: :email, target: "ops@example.com"}, attrs)
      )

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    channel.email_channel
    |> Ecto.Changeset.change(verified_at: now)
    |> Holter.Repo.update!()

    Delivery.get_channel!(channel.id)
  end

  describe "GET /api/v1/workspaces/:workspace_slug/notification_channels" do
    test "returns list of channels for workspace", %{
      conn: conn,
      workspace: workspace,
      api_spec: spec
    } do
      channel_fixture(workspace.id)

      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels")
      body = json_response(conn, 200)

      assert %{"data" => [_]} = body
      assert_schema(body, "NotificationChannelList", spec)
    end

    test "returns empty list when workspace has no channels", %{conn: conn, workspace: workspace} do
      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 404 for unknown workspace slug", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/workspaces/does-not-exist/notification_channels")
      assert json_response(conn, 404)
    end

    test "type=webhook filter only returns webhook channels", %{
      conn: conn,
      workspace: workspace
    } do
      channel_fixture(workspace.id, %{name: "Hook A"})
      channel_fixture(workspace.id, %{name: "Email A", type: :email, target: "a@example.com"})

      conn =
        get(
          conn,
          ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels?type=webhook"
        )

      types = json_response(conn, 200)["data"] |> Enum.map(& &1["type"])
      assert types == ["webhook"]
    end

    test "type=email filter only returns email channels", %{conn: conn, workspace: workspace} do
      channel_fixture(workspace.id, %{name: "Hook B"})
      channel_fixture(workspace.id, %{name: "Email B", type: :email, target: "b@example.com"})

      conn =
        get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels?type=email")

      types = json_response(conn, 200)["data"] |> Enum.map(& &1["type"])
      assert types == ["email"]
    end

    test "no type filter returns channels of all types", %{conn: conn, workspace: workspace} do
      channel_fixture(workspace.id, %{name: "Hook C"})
      channel_fixture(workspace.id, %{name: "Email C", type: :email, target: "c@example.com"})

      conn = get(conn, ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels")

      types =
        json_response(conn, 200)["data"]
        |> Enum.map(& &1["type"])
        |> Enum.sort()

      assert types == ["email", "webhook"]
    end

    test "an unknown type value is rejected by request validation", %{
      conn: conn,
      workspace: workspace
    } do
      conn =
        get(
          conn,
          ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels?type=slack"
        )

      assert response(conn, 422)
    end
  end

  describe "GET /api/v1/notification_channels/:id" do
    test "returns the channel", %{conn: conn, workspace: workspace, api_spec: spec} do
      channel = channel_fixture(workspace.id)

      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}")
      body = json_response(conn, 200)

      assert body["data"]["id"] == channel.id
      assert_schema(body, "NotificationChannelResponse", spec)
    end

    test "returns 404 for unknown channel id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/notification_channels/00000000-0000-0000-0000-000000000000")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/workspaces/:workspace_slug/notification_channels" do
    @valid_attrs %{name: "My Hook", type: "webhook", target: "https://hooks.example.com/notify"}

    test "creates a channel and returns 201", %{conn: conn, workspace: workspace, api_spec: spec} do
      conn =
        json_post(
          conn,
          ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels",
          @valid_attrs
        )

      body = json_response(conn, 201)

      assert body["data"]["name"] == "My Hook"
      assert_schema(body, "NotificationChannelResponse", spec)
    end

    test "returns 422 for missing required fields", %{conn: conn, workspace: workspace} do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels", %{
          name: "Bad"
        })

      assert json_response(conn, 422)
    end

    test "returns 422 for invalid webhook target URL", %{conn: conn, workspace: workspace} do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels", %{
          name: "Bad Hook",
          type: "webhook",
          target: "not-a-url"
        })

      resp = json_response(conn, 422)
      assert resp["error"]["code"] == "validation_failed"
    end

    test "ships a verification email when an email channel is created", %{
      conn: conn,
      workspace: workspace
    } do
      json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels", %{
        name: "Ops Email",
        type: "email",
        target: "ops@example.com"
      })

      assert_email_sent(to: "ops@example.com")
    end

    test "newly created email channels are not yet verified", %{
      conn: conn,
      workspace: workspace
    } do
      conn =
        json_post(conn, ~p"/api/v1/workspaces/#{workspace.slug}/notification_channels", %{
          name: "Ops Email",
          type: "email",
          target: "ops@example.com"
        })

      assert is_nil(json_response(conn, 201)["data"]["email_channel"]["verified_at"])
    end
  end

  describe "PUT /api/v1/notification_channels/:id" do
    test "updates the channel name", %{conn: conn, workspace: workspace, api_spec: spec} do
      channel = channel_fixture(workspace.id)

      conn =
        json_put(conn, ~p"/api/v1/notification_channels/#{channel.id}", %{name: "Updated Name"})

      body = json_response(conn, 200)

      assert body["data"]["name"] == "Updated Name"
      assert_schema(body, "NotificationChannelResponse", spec)
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn =
        json_put(
          conn,
          ~p"/api/v1/notification_channels/00000000-0000-0000-0000-000000000000",
          %{name: "X"}
        )

      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/v1/notification_channels/:id" do
    test "deletes the channel and returns 204", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      conn = delete(conn, ~p"/api/v1/notification_channels/#{channel.id}")

      assert response(conn, 204)
      assert {:error, :not_found} = Delivery.get_channel(channel.id)
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn =
        delete(conn, ~p"/api/v1/notification_channels/00000000-0000-0000-0000-000000000000")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/notification_channels/:id/pings" do
    test "enqueues a ping and returns 202", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      conn = post(conn, ~p"/api/v1/notification_channels/#{channel.id}/pings")

      assert response(conn, 202)
      assert_enqueued(worker: Holter.Delivery.Workers.WebhookDispatcher, args: %{"test" => true})
    end

    test "returns 404 for unknown channel", %{conn: conn} do
      conn =
        post(
          conn,
          ~p"/api/v1/notification_channels/00000000-0000-0000-0000-000000000000/pings"
        )

      assert json_response(conn, 404)
    end

    test "returns 422 with no_verified_recipients on an unverified email channel", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id, %{type: :email, target: "ops@example.com"})
      conn = post(conn, ~p"/api/v1/notification_channels/#{channel.id}/pings")
      assert json_response(conn, 422)["error"]["code"] == "no_verified_recipients"
    end

    test "does not enqueue a job when an email channel has no verified addresses", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id, %{type: :email, target: "ops@example.com"})
      post(conn, ~p"/api/v1/notification_channels/#{channel.id}/pings")
      assert all_enqueued(queue: :notifications) == []
    end

    test "returns 202 when an email channel's primary is verified", %{
      conn: conn,
      workspace: workspace
    } do
      channel = verified_email_channel_fixture(workspace.id)
      conn = post(conn, ~p"/api/v1/notification_channels/#{channel.id}/pings")
      assert response(conn, 202)
    end
  end

  describe "GET /api/v1/notification_channels/:id — nested subtype payload" do
    test "nests webhook fields under webhook_channel for webhook channels", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)
      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}")
      body = json_response(conn, 200)

      assert body["data"]["webhook_channel"]["url"] == channel.webhook_channel.url
    end

    test "exposes signing_token inside webhook_channel", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)
      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}")
      body = json_response(conn, 200)

      assert body["data"]["webhook_channel"]["signing_token"] ==
               channel.webhook_channel.signing_token
    end

    test "renders email_channel as null on a webhook channel", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)
      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}")
      assert json_response(conn, 200)["data"]["email_channel"] == nil
    end

    test "nests email fields under email_channel for email channels", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id, %{type: :email, target: "ops@example.com"})
      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}")
      body = json_response(conn, 200)

      assert body["data"]["email_channel"]["address"] == channel.email_channel.address
    end

    test "exposes anti_phishing_code inside email_channel", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id, %{type: :email, target: "ops@example.com"})
      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}")
      body = json_response(conn, 200)

      assert body["data"]["email_channel"]["anti_phishing_code"] ==
               channel.email_channel.anti_phishing_code
    end

    test "renders webhook_channel as null on an email channel", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id, %{type: :email, target: "ops@example.com"})
      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}")
      assert json_response(conn, 200)["data"]["webhook_channel"] == nil
    end

    test "renders email_channel.verified_at as null while pending", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id, %{type: :email, target: "ops@example.com"})
      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}")
      assert is_nil(json_response(conn, 200)["data"]["email_channel"]["verified_at"])
    end

    test "renders email_channel.verified_at as a timestamp once verified", %{
      conn: conn,
      workspace: workspace,
      api_spec: spec
    } do
      channel = verified_email_channel_fixture(workspace.id)
      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}")
      body = json_response(conn, 200)

      assert {:ok, %DateTime{}, _} =
               DateTime.from_iso8601(body["data"]["email_channel"]["verified_at"])

      assert_schema(body, "NotificationChannelResponse", spec)
    end

    test "renders an empty recipients array when no CCs have been added", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id, %{type: :email, target: "ops@example.com"})
      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}")
      assert json_response(conn, 200)["data"]["email_channel"]["recipients"] == []
    end

    test "exposes the CC recipient list with verified_at per row", %{
      conn: conn,
      workspace: workspace,
      api_spec: spec
    } do
      channel = channel_fixture(workspace.id, %{type: :email, target: "ops@example.com"})
      {:ok, pending} = Delivery.add_recipient(channel.id, "pending@example.com")
      {:ok, verified} = Delivery.add_recipient(channel.id, "verified@example.com")
      Delivery.verify_recipient(verified.token)

      conn = get(conn, ~p"/api/v1/notification_channels/#{channel.id}")
      body = json_response(conn, 200)

      recipients =
        body["data"]["email_channel"]["recipients"]
        |> Enum.sort_by(& &1["email"])

      assert [
               %{"email" => "pending@example.com", "verified_at" => nil, "id" => pending_id},
               %{
                 "email" => "verified@example.com",
                 "verified_at" => verified_at_string,
                 "id" => verified_id
               }
             ] = recipients

      assert pending_id == pending.id
      assert verified_id == verified.id
      assert {:ok, %DateTime{}, _} = DateTime.from_iso8601(verified_at_string)
      assert_schema(body, "NotificationChannelResponse", spec)
    end
  end

  describe "PUT /api/v1/notification_channels/:id/signing_token" do
    test "rotates the signing token and returns the new value", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)
      original = channel.webhook_channel.signing_token

      conn = json_put(conn, ~p"/api/v1/notification_channels/#{channel.id}/signing_token", %{})

      body = json_response(conn, 200)
      assert is_binary(body["data"]["webhook_channel"]["signing_token"])
      assert body["data"]["webhook_channel"]["signing_token"] != original
    end

    test "persists the rotated signing_token to the database", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)

      json_put(conn, ~p"/api/v1/notification_channels/#{channel.id}/signing_token", %{})

      reloaded =
        Holter.Repo.get_by!(Holter.Delivery.WebhookChannel, notification_channel_id: channel.id)

      refute reloaded.signing_token == channel.webhook_channel.signing_token
    end

    test "returns 422 with not_a_webhook_channel for an email channel", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id, %{type: :email, target: "ops@example.com"})

      conn = json_put(conn, ~p"/api/v1/notification_channels/#{channel.id}/signing_token", %{})

      body = json_response(conn, 422)
      assert body["error"]["code"] == "not_a_webhook_channel"
    end

    test "returns 404 for unknown channel id", %{conn: conn} do
      conn =
        json_put(
          conn,
          ~p"/api/v1/notification_channels/00000000-0000-0000-0000-000000000000/signing_token",
          %{}
        )

      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/v1/notification_channels/:id/anti_phishing_code" do
    test "rotates the anti_phishing_code and returns the new value", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id, %{type: :email, target: "ops@example.com"})
      original = channel.email_channel.anti_phishing_code

      conn =
        json_put(conn, ~p"/api/v1/notification_channels/#{channel.id}/anti_phishing_code", %{})

      body = json_response(conn, 200)
      assert body["data"]["email_channel"]["anti_phishing_code"] != original
    end

    test "persists the rotated anti_phishing_code to the database", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id, %{type: :email, target: "ops@example.com"})

      json_put(
        conn,
        ~p"/api/v1/notification_channels/#{channel.id}/anti_phishing_code",
        %{}
      )

      reloaded =
        Holter.Repo.get_by!(Holter.Delivery.EmailChannel, notification_channel_id: channel.id)

      refute reloaded.anti_phishing_code == channel.email_channel.anti_phishing_code
    end

    test "returns 422 with not_an_email_channel for a webhook channel", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)

      conn =
        json_put(conn, ~p"/api/v1/notification_channels/#{channel.id}/anti_phishing_code", %{})

      body = json_response(conn, 422)
      assert body["error"]["code"] == "not_an_email_channel"
    end

    test "returns 404 for unknown channel id", %{conn: conn} do
      conn =
        json_put(
          conn,
          ~p"/api/v1/notification_channels/00000000-0000-0000-0000-000000000000/anti_phishing_code",
          %{}
        )

      assert json_response(conn, 404)
    end
  end
end
