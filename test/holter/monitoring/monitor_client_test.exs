defmodule Holter.Monitoring.MonitorClientTest do
  use ExUnit.Case, async: true
  alias Holter.Monitoring.MonitorClient.HTTP
  alias Holter.Test.DummyService

  setup do
    DummyService.reset()
    port = Application.get_env(:holter, :dummy_port)
    base_url = "http://localhost:#{port}/probe"
    %{base_url: base_url}
  end

  describe "request/1" do
    test "successfully performs a request", %{base_url: base_url} do
      DummyService.enqueue("test-req", status: 200, body: "Success")

      assert {:ok, %Req.Response{status: 200, body: "Success"}} =
               HTTP.request(url: "#{base_url}/test-req")
    end

    test "handles server errors", %{base_url: base_url} do
      DummyService.enqueue("test-err", status: 500, body: "Internal Error")

      assert {:ok, %Req.Response{status: 500, body: "Internal Error"}} =
               HTTP.request(url: "#{base_url}/test-err")
    end

    test "retry logic is configured for exceptions" do
      opts = [url: "http://localhost:1", max_retries: 0]
      assert {:error, _} = HTTP.request(opts)
    end
  end

  describe "get_ssl_expiration/1" do
    @tag :external
    test "fetches expiration from a real domain" do
      assert {:ok, %DateTime{}} = HTTP.get_ssl_expiration("https://google.com")
    end

    test "returns error for invalid domain" do
      assert {:error, _} = HTTP.get_ssl_expiration("https://non-existent-domain-123456.local")
    end
  end
end
