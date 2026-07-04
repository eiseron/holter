defmodule Holter.SentryFinchClientTest do
  use ExUnit.Case, async: false

  alias Holter.SentryFinchClient
  alias Holter.Test.DummyService

  setup do
    DummyService.reset()
    port = Application.get_env(:holter, :dummy_port)
    %{base_url: "http://localhost:#{port}/probe"}
  end

  describe "child_spec/0" do
    test "names the Finch pool as Holter.SentryFinchClient" do
      {_mod, _fun, [opts]} = SentryFinchClient.child_spec().start
      assert opts[:name] == Holter.SentryFinchClient
    end
  end

  describe "post/3" do
    test "returns {:ok, status, headers, body} on a successful response", %{base_url: base_url} do
      DummyService.enqueue("sentry-ok", status: 200, body: "accepted")

      assert {:ok, 200, _headers, "accepted"} =
               SentryFinchClient.post("#{base_url}/sentry-ok", [], "{}")
    end

    test "propagates non-200 status codes as {:ok, status, _, _}", %{base_url: base_url} do
      DummyService.enqueue("sentry-4xx", status: 429, body: "rate limited")

      assert {:ok, 429, _headers, "rate limited"} =
               SentryFinchClient.post("#{base_url}/sentry-4xx", [], "{}")
    end

    test "forwards request headers to the server", %{base_url: base_url} do
      DummyService.enqueue("sentry-hdr", status: 200, body: "ok")

      SentryFinchClient.post(
        "#{base_url}/sentry-hdr",
        [{"x-sentry-auth", "Sentry sentry_key=abc123"}],
        "{}"
      )

      [request | _] = DummyService.get_requests()
      header_names = Enum.map(request.req_headers, fn {k, _} -> k end)
      assert "x-sentry-auth" in header_names
    end

    test "returns {:error, reason} when the host cannot be reached" do
      assert {:error, _reason} =
               SentryFinchClient.post("http://non-existent-sentry-host.invalid/api", [], "{}")
    end
  end
end
