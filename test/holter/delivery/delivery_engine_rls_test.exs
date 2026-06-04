defmodule Holter.Delivery.EngineRLSTest do
  use Holter.DataCase, async: false
  use Oban.Testing, repo: Holter.Repo

  import Holter.RLSHelpers, only: [setup_app_role: 0]

  alias Holter.Delivery.{EmailChannels, Engine, WebhookChannels}
  alias Holter.Delivery.Workers.{EmailDispatcher, WebhookDispatcher}

  defp webhook_channel_for(workspace_id, monitor_id) do
    {:ok, channel} =
      WebhookChannels.create(%{
        workspace_id: workspace_id,
        name: "Webhook",
        url: "https://example.com/hook"
      })

    WebhookChannels.link_monitor(monitor_id, channel.id)
    channel
  end

  defp email_channel_for(workspace_id, monitor_id) do
    {:ok, channel} = EmailChannels.create(%{workspace_id: workspace_id, name: "Email"})
    {:ok, recipient} = EmailChannels.add_recipient(channel.id, "ops@example.com")
    {:ok, _} = EmailChannels.verify_recipient(recipient.token)
    EmailChannels.link_monitor(monitor_id, channel.id)
    channel
  end

  setup do
    user = user_fixture()
    workspace = workspace_fixture_for(user)
    monitor = monitor_fixture(workspace_id: workspace.id)
    incident = incident_fixture(monitor_id: monitor.id)
    webhook = webhook_channel_for(workspace.id, monitor.id)
    email = email_channel_for(workspace.id, monitor.id)

    stranger = user_fixture()
    stranger_ws = workspace_fixture_for(stranger)
    stranger_monitor = monitor_fixture(workspace_id: stranger_ws.id)
    _stranger_webhook = webhook_channel_for(stranger_ws.id, stranger_monitor.id)

    setup_app_role()

    %{
      workspace: workspace,
      monitor: monitor,
      incident: incident,
      webhook: webhook,
      email: email,
      stranger_monitor: stranger_monitor
    }
  end

  describe "dispatch_incident/4 under holter_app FORCE RLS" do
    test "enqueues a WebhookDispatcher job for the workspace's linked channel", ctx do
      Engine.dispatch_incident(ctx.incident, :down)

      assert_enqueued(
        worker: WebhookDispatcher,
        args: %{"webhook_channel_id" => ctx.webhook.id, "workspace_id" => ctx.workspace.id}
      )
    end

    test "enqueues an EmailDispatcher job for the workspace's linked channel", ctx do
      Engine.dispatch_incident(ctx.incident, :down)

      assert_enqueued(
        worker: EmailDispatcher,
        args: %{"email_channel_id" => ctx.email.id, "workspace_id" => ctx.workspace.id}
      )
    end

    test "a workspace's stamp cannot see another workspace's channels", ctx do
      incident = %{
        id: ctx.incident.id,
        monitor_id: ctx.stranger_monitor.id,
        workspace_id: ctx.workspace.id
      }

      Engine.dispatch_incident(incident, :down)

      assert all_enqueued(queue: :notifications) == []
    end
  end
end
