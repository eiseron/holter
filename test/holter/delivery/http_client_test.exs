defmodule Holter.Delivery.HttpClientTest do
  use ExUnit.Case, async: false

  alias Holter.Delivery.HttpClient
  alias Holter.Delivery.HttpClient.HTTP
  alias Holter.Test.DummyService

  @port Application.compile_env(:holter, :dummy_port, 4001)
  @base "http://localhost:#{@port}"

  setup do
    DummyService.reset()
    :ok
  end

  describe "impl/0 default" do
    test "default impl is a loaded module" do
      original = Application.get_env(:holter, :delivery_http_client)
      Application.delete_env(:holter, :delivery_http_client)

      try do
        assert Code.ensure_loaded?(HttpClient.impl())
      after
        unless is_nil(original) do
          Application.put_env(:holter, :delivery_http_client, original)
        end
      end
    end

    test "default impl exports post/3 — guards against unqualified module aliases" do
      original = Application.get_env(:holter, :delivery_http_client)
      Application.delete_env(:holter, :delivery_http_client)

      try do
        impl = HttpClient.impl()
        Code.ensure_loaded(impl)
        assert function_exported?(impl, :post, 3)
      after
        unless is_nil(original) do
          Application.put_env(:holter, :delivery_http_client, original)
        end
      end
    end
  end

  describe "redirect following" do
    test "301 redirect is not followed — response status is 301, not the redirect destination's status" do
      DummyService.enqueue("redirect-destination", status: 200, body: "internal secret")

      DummyService.enqueue("redirect-source",
        status: 301,
        headers: [{"location", "#{@base}/probe/redirect-destination"}]
      )

      assert {:ok, %{status: 301}} =
               HTTP.post("#{@base}/probe/redirect-source", "{}", [
                 {"content-type", "application/json"}
               ])
    end

    test "301 redirect is not followed — redirect destination receives no request" do
      DummyService.enqueue("redirect-destination-b", status: 200, body: "internal secret")

      DummyService.enqueue("redirect-source-b",
        status: 301,
        headers: [{"location", "#{@base}/probe/redirect-destination-b"}]
      )

      HTTP.post("#{@base}/probe/redirect-source-b", "{}", [])

      destination_hits =
        DummyService.get_requests()
        |> Enum.count(&(&1.request_path == "/probe/redirect-destination-b"))

      assert destination_hits == 0
    end

    test "302 redirect is not followed" do
      DummyService.enqueue("redir-302-dest", status: 200, body: "should not reach here")

      DummyService.enqueue("redir-302-source",
        status: 302,
        headers: [{"location", "#{@base}/probe/redir-302-dest"}]
      )

      assert {:ok, %{status: 302}} =
               HTTP.post("#{@base}/probe/redir-302-source", "{}", [])
    end
  end

  describe "request timeout" do
    @tag timeout: 5_000
    test "slow server that never responds returns an error within the configured timeout" do
      DummyService.enqueue("slow-hook", status: 200, body: "OK", delay: 10_000)

      assert {:error, _reason} =
               HTTP.post("#{@base}/probe/slow-hook", "{}", [{"content-type", "application/json"}])
    end
  end

  describe "response body handling" do
    test "1 MB response body completes and returns only the status code" do
      large_body = String.duplicate("x", 1_024 * 1_024)
      DummyService.enqueue("large-response", status: 200, body: large_body)

      assert {:ok, %{status: 200}} = HTTP.post("#{@base}/probe/large-response", "{}", [])
    end

    test "return value contains only the status key — response body is not propagated" do
      DummyService.enqueue("with-body", status: 200, body: "some response payload")

      {:ok, response} = HTTP.post("#{@base}/probe/with-body", "{}", [])

      assert Map.keys(response) == [:status]
    end
  end
end
