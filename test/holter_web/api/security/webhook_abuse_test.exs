defmodule HolterWeb.Api.Security.WebhookAbuseTest do
  use HolterWeb.ConnCase, async: false
  use Oban.Testing, repo: Holter.Repo

  alias Holter.Delivery.{Engine, WebhookChannels}

  setup %{conn: conn} do
    workspace = workspace_fixture()

    {:ok, channel} =
      WebhookChannels.create(%{
        workspace_id: workspace.id,
        name: "Test Hook",
        url: "https://example.com/hook"
      })

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")

    {:ok, conn: conn, workspace: workspace, channel: channel}
  end

  describe "SSRF prevention — channel create via API" do
    test "creating a webhook channel with http://localhost target returns 422",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "http://localhost/hook")
      resp = json_response(conn, 422)
      assert resp["error"]["code"] == "validation_failed"
    end

    test "creating a webhook channel with http://127.0.0.1 target returns 422",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "http://127.0.0.1/hook")
      assert json_response(conn, 422)
    end

    test "creating a webhook channel with http://169.254.169.254 target returns 422",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "http://169.254.169.254/latest/meta-data")
      assert json_response(conn, 422)
    end

    test "creating a webhook channel with http://192.168.1.1 target returns 422",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "http://192.168.1.1/hook")
      assert json_response(conn, 422)
    end

    test "creating a webhook channel with a public URL succeeds",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "https://hooks.example.com/ok")
      assert json_response(conn, 201)
    end
  end

  describe "SSRF prevention — additional address forms via API" do
    test "IPv6 loopback http://[::1]/hook returns 422",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "http://[::1]/hook")
      assert json_response(conn, 422)
    end

    test "IPv4-mapped IPv6 http://[::ffff:127.0.0.1]/hook returns 422",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "http://[::ffff:127.0.0.1]/hook")
      assert json_response(conn, 422)
    end

    test "IPv6 ULA http://[fc00::1]/hook returns 422",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "http://[fc00::1]/hook")
      assert json_response(conn, 422)
    end

    test "IPv6 link-local http://[fe80::1]/hook returns 422",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "http://[fe80::1]/hook")
      assert json_response(conn, 422)
    end

    test "non-private IPv6 (Cloudflare DNS) http://[2606:4700:4700::1111]/hook returns 201",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "http://[2606:4700:4700::1111]/hook")
      assert json_response(conn, 201)
    end

    test "URL with userinfo (basic auth credentials) returns 422",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "http://user:pass@hooks.example.com/hook")
      assert json_response(conn, 422)
    end

    test "URL with userinfo carrying only a username returns 422",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "http://attacker@hooks.example.com/hook")
      assert json_response(conn, 422)
    end

    test "URL with non-default but public destination is accepted",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "https://api.external-service.com:8443/events")
      assert json_response(conn, 201)
    end
  end

  describe "SSRF prevention — additional address forms via update" do
    test "IPv6 loopback rejected on update",
         %{conn: conn, channel: channel} do
      conn =
        put(
          conn,
          ~p"/api/v1/webhook_channels/#{channel.id}",
          Jason.encode!(%{url: "http://[::1]/hook"})
        )

      assert json_response(conn, 422)
    end

    test "IPv6 ULA rejected on update",
         %{conn: conn, channel: channel} do
      conn =
        put(
          conn,
          ~p"/api/v1/webhook_channels/#{channel.id}",
          Jason.encode!(%{url: "http://[fc00::1]/hook"})
        )

      assert json_response(conn, 422)
    end

    test "URL with userinfo rejected on update",
         %{conn: conn, channel: channel} do
      conn =
        put(
          conn,
          ~p"/api/v1/webhook_channels/#{channel.id}",
          Jason.encode!(%{url: "http://user:pass@example.com/hook"})
        )

      assert json_response(conn, 422)
    end
  end

  describe "Malformed payloads — channel create" do
    test "URL with empty string returns 422",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "")
      assert json_response(conn, 422)
    end

    test "URL with whitespace inside the host returns 422",
         %{conn: conn, workspace: workspace} do
      conn = post_channel(conn, workspace, "https://exa mple.com/")
      assert json_response(conn, 422)
    end

    test "URL omitted entirely returns 422",
         %{conn: conn, workspace: workspace} do
      conn =
        post(
          conn,
          ~p"/api/v1/workspaces/#{workspace.slug}/webhook_channels",
          Jason.encode!(%{name: "Hook"})
        )

      assert json_response(conn, 422)
    end

    test "settings payload over 4 KB encoded is rejected",
         %{conn: conn, workspace: workspace} do
      big_settings = %{"x" => String.duplicate("a", 5000)}

      conn =
        post(
          conn,
          ~p"/api/v1/workspaces/#{workspace.slug}/webhook_channels",
          Jason.encode!(%{
            name: "Hook",
            url: "https://example.com/hook",
            settings: big_settings
          })
        )

      assert json_response(conn, 422)
    end

    test "settings payload at 3 KB encoded is accepted",
         %{conn: conn, workspace: workspace} do
      ok_settings = %{"x" => String.duplicate("a", 3000)}

      conn =
        post(
          conn,
          ~p"/api/v1/workspaces/#{workspace.slug}/webhook_channels",
          Jason.encode!(%{
            name: "Hook",
            url: "https://example.com/hook",
            settings: ok_settings
          })
        )

      assert json_response(conn, 201)
    end
  end

  describe "test dispatch — per-channel cooldown" do
    test "first ping returns 202 and enqueues exactly one job",
         %{conn: conn, channel: channel} do
      conn = post(conn, ~p"/api/v1/webhook_channels/#{channel.id}/pings")

      assert response(conn, :accepted)
      assert length(all_enqueued(queue: :notifications)) == 1
    end

    test "second ping in rapid succession returns 429 with rate-limit error code",
         %{conn: conn, channel: channel} do
      post(conn, ~p"/api/v1/webhook_channels/#{channel.id}/pings")
      conn2 = post(conn, ~p"/api/v1/webhook_channels/#{channel.id}/pings")

      body = json_response(conn2, 429)
      assert body["error"]["code"] == "test_dispatch_rate_limited"
    end

    test "five back-to-back pings enqueue exactly one job (others rejected at the gate)",
         %{conn: conn, channel: channel} do
      Enum.each(1..5, fn _ ->
        post(conn, ~p"/api/v1/webhook_channels/#{channel.id}/pings")
      end)

      assert length(all_enqueued(queue: :notifications)) == 1
    end

    test "cooldown is per-channel — second channel can ping while first is throttled",
         %{conn: conn, workspace: workspace, channel: first_channel} do
      {:ok, second_channel} =
        WebhookChannels.create(%{
          workspace_id: workspace.id,
          name: "Other Hook",
          url: "https://example.com/other"
        })

      post(conn, ~p"/api/v1/webhook_channels/#{first_channel.id}/pings")
      conn2 = post(conn, ~p"/api/v1/webhook_channels/#{second_channel.id}/pings")

      assert response(conn2, :accepted)
    end

    test "ping is allowed again once the cooldown elapses",
         %{conn: conn, channel: channel} do
      post(conn, ~p"/api/v1/webhook_channels/#{channel.id}/pings")

      backdate_test_dispatch(channel.id, Engine.test_dispatch_cooldown() + 1)

      conn2 = post(conn, ~p"/api/v1/webhook_channels/#{channel.id}/pings")
      assert response(conn2, :accepted)
    end
  end

  defp post_channel(conn, workspace, url) do
    post(
      conn,
      ~p"/api/v1/workspaces/#{workspace.slug}/webhook_channels",
      Jason.encode!(%{name: "Hook", url: url})
    )
  end

  defp backdate_test_dispatch(channel_id, seconds_ago) do
    past =
      DateTime.utc_now()
      |> DateTime.add(-seconds_ago, :second)
      |> DateTime.truncate(:second)

    cond do
      wc = Holter.Repo.get(Holter.Delivery.WebhookChannel, channel_id) ->
        wc |> Ecto.Changeset.change(last_test_dispatched_at: past) |> Holter.Repo.update!()

      ec = Holter.Repo.get(Holter.Delivery.EmailChannel, channel_id) ->
        ec |> Ecto.Changeset.change(last_test_dispatched_at: past) |> Holter.Repo.update!()

      true ->
        :ok
    end
  end
end
