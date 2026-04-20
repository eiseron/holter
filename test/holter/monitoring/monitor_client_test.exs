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

    test "includes the custom Holter User-Agent in requests", %{base_url: base_url} do
      DummyService.enqueue("ua-test", status: 200, body: "OK")

      {:ok, _response} = HTTP.request(url: "#{base_url}/ua-test")

      [request | _] = DummyService.get_requests()

      user_agent =
        request.req_headers
        |> Enum.find_value(fn {k, v} -> if k == "user-agent", do: v end)

      version = Application.spec(:holter, :vsn) |> to_string()
      domain = System.get_env("APP_DOMAIN", "holter.dev")

      assert user_agent =~ "Holter/#{version}"
      assert user_agent =~ "(+https://#{domain})"
    end
  end

  describe "body_within_limit?/2" do
    @max_body_bytes 5 * 1024 * 1024

    test "returns true for a small binary body" do
      assert HTTP.body_within_limit?("small body")
    end

    test "returns true for a body exactly at the limit" do
      assert HTTP.body_within_limit?(String.duplicate("x", @max_body_bytes))
    end

    test "returns false when body exceeds limit by one byte" do
      refute HTTP.body_within_limit?(String.duplicate("x", @max_body_bytes + 1))
    end

    test "returns true for non-binary value (decoded JSON map)" do
      assert HTTP.body_within_limit?(%{"key" => "value"})
    end

    test "returns true for empty binary" do
      assert HTTP.body_within_limit?("")
    end

    test "uses custom limit when provided" do
      refute HTTP.body_within_limit?("hello", 3)
    end
  end

  describe "request/1 body size enforcement" do
    @max_body_bytes 5 * 1024 * 1024

    test "returns {:error, RuntimeError} when response body exceeds max bytes", %{
      base_url: base_url
    } do
      DummyService.enqueue("body-size-exceed", body: String.duplicate("a", @max_body_bytes + 1))

      result = HTTP.request(url: "#{base_url}/body-size-exceed")
      assert {:error, %RuntimeError{}} = result
    end

    test "error message mentions body is too large", %{base_url: base_url} do
      DummyService.enqueue("body-size-msg", body: String.duplicate("a", @max_body_bytes + 1))

      {:error, error} = HTTP.request(url: "#{base_url}/body-size-msg")
      assert error.message =~ "too large"
    end

    test "returns {:ok, response} when body is within limit", %{base_url: base_url} do
      DummyService.enqueue("body-size-ok", status: 200, body: "small response")

      assert {:ok, _response} = HTTP.request(url: "#{base_url}/body-size-ok")
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
