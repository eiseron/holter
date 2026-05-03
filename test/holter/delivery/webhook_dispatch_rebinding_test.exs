defmodule Holter.Delivery.WebhookDispatchRebindingTest do
  @moduledoc """
  End-to-end pinning test for #34: a webhook dispatch through the real
  Oban worker + real HttpClient.HTTP must refuse to fire when DNS
  resolution returns a private IP at dispatch time.

  Bypasses the usual HttpClientMock so the DNS guard inside
  `Holter.Delivery.HttpClient.HTTP.post/3` is exercised end-to-end.
  """
  use Holter.DataCase, async: false
  use Oban.Testing, repo: Holter.Repo

  import ExUnit.CaptureLog
  import Mox

  alias Holter.Delivery.HttpClient.HTTP, as: RealHttpClient
  alias Holter.Delivery.WebhookChannels
  alias Holter.Delivery.Workers.WebhookDispatcher
  alias Holter.Network.ResolverMock
  alias Holter.Test.DummyService

  setup :verify_on_exit!

  setup do
    original_client = Application.get_env(:holter, :delivery_http_client)
    Application.put_env(:holter, :delivery_http_client, RealHttpClient)
    DummyService.reset()

    on_exit(fn ->
      Application.put_env(:holter, :delivery_http_client, original_client)
      DummyService.reset()
      Application.put_env(:holter, :network, [])
    end)

    ws = workspace_fixture()

    {:ok, channel} =
      WebhookChannels.create(%{
        workspace_id: ws.id,
        name: "Rebinding hook",
        url: "https://rebind-victim.example.com/hook"
      })

    %{channel: channel}
  end

  test "test ping refuses to dispatch when DNS resolves to a private IP", %{channel: channel} do
    Mox.set_mox_global()

    expect(ResolverMock, :getaddrs, fn ~c"rebind-victim.example.com", :inet ->
      {:ok, [{10, 0, 0, 1}]}
    end)

    log =
      capture_log(fn ->
        result =
          perform_job(WebhookDispatcher, %{
            "webhook_channel_id" => channel.id,
            "test" => true
          })

        assert match?(
                 {:error, %RuntimeError{message: "destination rejected: private_host"}},
                 result
               )
      end)

    assert log =~ "blocked dispatch"
    assert log =~ "rebind-victim.example.com"
    assert DummyService.get_requests() == []
  end
end
