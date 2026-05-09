defmodule Holter.Delivery.Workers.EmailDispatcherRLSTest do
  @moduledoc """
  Regression coverage for the bug where EmailDispatcher silently failed
  in preview/prod because `EmailChannels.get!/1` ran without a tenant
  pinned and RLS hid the row. The job retried 20× then went to
  `:discarded`, leaving the email_channel logs page empty for hours.

  These tests run under the `holter_app` role so the policy actually
  fires. They assert the job's *side effect* (the email landed in
  Swoosh's test mailbox with the verified recipient in bcc), not just
  that `perform/1` returned `:ok` — silently swallowing exceptions
  inside the wrap would still pass an `:ok` check.
  """

  use Holter.DataCase, async: false
  use Oban.Testing, repo: Holter.Repo

  import Holter.RLSHelpers, only: [setup_app_role: 0]
  import Swoosh.TestAssertions

  alias Holter.Delivery.{EmailChannels, Engine}
  alias Holter.Delivery.Workers.EmailDispatcher
  alias Holter.Repo.Tenant

  @recipient_email "alice@example.com"

  setup do
    user = user_fixture()
    workspace = workspace_fixture_for(user)

    {:ok, channel} =
      EmailChannels.create(%{workspace_id: workspace.id, name: "Alerts"})

    {:ok, recipient} = EmailChannels.add_recipient(channel.id, @recipient_email)

    {:ok, _verified} =
      Holter.Repo.update(
        Ecto.Changeset.change(recipient,
          verified_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
          token: nil,
          token_expires_at: nil
        )
      )

    setup_app_role()

    %{workspace: workspace, channel: channel}
  end

  test "the test-email job delivers to the verified recipient under holter_app",
       %{channel: channel, workspace: workspace} do
    EmailDispatcher.perform(%Oban.Job{
      args: %{
        "email_channel_id" => channel.id,
        "workspace_id" => workspace.id,
        "test" => true
      }
    })

    assert_email_sent(bcc: [{"", @recipient_email}])
  end

  test "Engine.dispatch_test_email enqueues the job with workspace_id in args",
       %{channel: channel, workspace: workspace} do
    Tenant.with_workspace!(workspace.id, fn -> Engine.dispatch_test_email(channel.id) end)

    assert_enqueued(
      worker: EmailDispatcher,
      args: %{
        "email_channel_id" => channel.id,
        "workspace_id" => workspace.id,
        "test" => true
      }
    )
  end

  test "draining the queue under holter_app delivers the email to the recipient",
       %{channel: channel, workspace: workspace} do
    {:ok, _oban_job} =
      Tenant.with_workspace!(workspace.id, fn -> Engine.dispatch_test_email(channel.id) end)

    perform_job(
      EmailDispatcher,
      %{
        "email_channel_id" => channel.id,
        "workspace_id" => channel.workspace_id,
        "test" => true
      }
    )

    assert_email_sent(bcc: [{"", @recipient_email}])
  end

  test "without workspace_id in args the dispatcher raises immediately rather than silently retrying",
       %{channel: channel} do
    job = %Oban.Job{
      args: %{"email_channel_id" => channel.id, "test" => true}
    }

    assert_raise ArgumentError, ~r/requires "workspace_id"/, fn ->
      EmailDispatcher.perform(job)
    end
  end
end
