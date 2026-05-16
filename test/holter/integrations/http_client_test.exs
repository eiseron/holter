defmodule Holter.Integrations.HttpClientTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mox

  alias Holter.Integrations.HttpClient
  alias Holter.Integrations.HttpClient.HTTP
  alias Holter.Network.ResolverMock
  alias Holter.Test.DummyService

  @port Application.compile_env(:holter, :dummy_port, 4001)
  @base "http://localhost:#{@port}"

  setup :verify_on_exit!

  setup do
    DummyService.reset()
    Application.put_env(:holter, :network, trusted_hosts: ["localhost", "127.0.0.1"])
    stub_with(ResolverMock, Holter.Test.StubResolver)

    on_exit(fn ->
      DummyService.reset()
      Application.put_env(:holter, :network, [])
    end)

    :ok
  end

  describe "impl/0" do
    test "returns a module that exports post/3" do
      original = Application.get_env(:holter, :integrations_http_client)
      Application.delete_env(:holter, :integrations_http_client)

      try do
        impl = HttpClient.impl()
        Code.ensure_loaded(impl)
        assert function_exported?(impl, :post, 3)
      after
        unless is_nil(original) do
          Application.put_env(:holter, :integrations_http_client, original)
        end
      end
    end

    test "returns a module that exports get/2" do
      original = Application.get_env(:holter, :integrations_http_client)
      Application.delete_env(:holter, :integrations_http_client)

      try do
        impl = HttpClient.impl()
        Code.ensure_loaded(impl)
        assert function_exported?(impl, :get, 2)
      after
        unless is_nil(original) do
          Application.put_env(:holter, :integrations_http_client, original)
        end
      end
    end
  end

  describe "HTTP.post/3 — SSRF protection" do
    test "rejects private IP resolved via DNS and returns error tuple" do
      expect(ResolverMock, :getaddrs, fn _, :inet -> {:ok, [{10, 0, 0, 1}]} end)

      capture_log(fn ->
        assert {:error, %RuntimeError{message: "destination rejected: private_host"}} =
                 HTTP.post("https://attacker.example.com/hook", "{}", [])
      end)
    end

    test "logs a warning when request is blocked" do
      expect(ResolverMock, :getaddrs, fn _, :inet -> {:ok, [{10, 0, 0, 1}]} end)

      log = capture_log(fn -> HTTP.post("https://attacker.example.com/hook", "{}", []) end)

      assert log =~ "blocked"
    end

    test "rejects URL with embedded CRLF control characters" do
      expect(ResolverMock, :getaddrs, 0, fn _, _ -> flunk("resolver must not be called") end)

      capture_log(fn ->
        assert {:error, %RuntimeError{message: "destination rejected: control_chars"}} =
                 HTTP.post("https://example.com\r\n/hook", "{}", [])
      end)
    end

    test "rejects URL with userinfo credentials" do
      expect(ResolverMock, :getaddrs, 0, fn _, _ -> flunk("resolver must not be called") end)

      capture_log(fn ->
        assert {:error, %RuntimeError{message: "destination rejected: credentials"}} =
                 HTTP.post("https://user:pass@api.example.com/hook", "{}", [])
      end)
    end

    test "rejects unresolvable hostname" do
      expect(ResolverMock, :getaddrs, fn _, :inet -> {:error, :nxdomain} end)

      capture_log(fn ->
        assert {:error, %RuntimeError{message: "destination rejected: unresolved"}} =
                 HTTP.post("https://no-such-host.invalid/hook", "{}", [])
      end)
    end
  end

  describe "HTTP.get/2 — SSRF protection" do
    test "rejects private IP resolved via DNS" do
      expect(ResolverMock, :getaddrs, fn _, :inet -> {:ok, [{192, 168, 1, 1}]} end)

      capture_log(fn ->
        assert {:error, %RuntimeError{message: "destination rejected: private_host"}} =
                 HTTP.get("https://attacker.example.com/resource", [])
      end)
    end

    test "rejects URL with userinfo credentials" do
      expect(ResolverMock, :getaddrs, 0, fn _, _ -> flunk("resolver must not be called") end)

      capture_log(fn ->
        assert {:error, %RuntimeError{message: "destination rejected: credentials"}} =
                 HTTP.get("https://user:pass@api.example.com/token", [])
      end)
    end
  end

  describe "HTTP.post/3 — successful dispatch" do
    test "returns {:ok, %{status: status}} on successful request to trusted host" do
      DummyService.enqueue("integrations-post-ok", status: 200, body: "OK")

      assert {:ok, %{status: 200}} =
               HTTP.post("#{@base}/probe/integrations-post-ok", "{}", [
                 {"content-type", "application/json"}
               ])
    end

    test "dispatches when URL uses a trusted IP directly (no hostname rewrite needed)" do
      DummyService.enqueue("integrations-direct-ip", status: 200, body: "OK")

      expect(ResolverMock, :getaddrs, fn ~c"127.0.0.1", :inet ->
        {:ok, [{127, 0, 0, 1}]}
      end)

      assert {:ok, %{status: 200}} =
               HTTP.post("http://127.0.0.1:#{@port}/probe/integrations-direct-ip", "{}", [])
    end

    test "includes response body in return value" do
      DummyService.enqueue("integrations-post-body", status: 201, body: "created")

      assert {:ok, %{body: _}} = HTTP.post("#{@base}/probe/integrations-post-body", "{}", [])
    end

    test "preserves original Host header after IP rewrite" do
      DummyService.enqueue("integrations-host-header", status: 200, body: "OK")

      HTTP.post("#{@base}/probe/integrations-host-header", "{}", [])

      [conn] = DummyService.get_requests()
      assert conn.host == "localhost"
    end

    test "does not follow redirects" do
      DummyService.enqueue("integrations-redir-dest", status: 200, body: "secret")

      DummyService.enqueue("integrations-redir-src",
        status: 301,
        headers: [{"location", "#{@base}/probe/integrations-redir-dest"}]
      )

      assert {:ok, %{status: 301}} =
               HTTP.post("#{@base}/probe/integrations-redir-src", "{}", [])
    end
  end

  describe "HTTP.get/2 — successful dispatch" do
    test "returns {:ok, %{status: status}} on successful GET to trusted host" do
      DummyService.enqueue("integrations-get-ok", status: 200, body: "data")

      assert {:ok, %{status: 200}} = HTTP.get("#{@base}/probe/integrations-get-ok", [])
    end

    test "does not follow redirects on GET" do
      DummyService.enqueue("integrations-get-redir-dest", status: 200, body: "secret")

      DummyService.enqueue("integrations-get-redir-src",
        status: 302,
        headers: [{"location", "#{@base}/probe/integrations-get-redir-dest"}]
      )

      assert {:ok, %{status: 302}} = HTTP.get("#{@base}/probe/integrations-get-redir-src", [])
    end
  end
end
