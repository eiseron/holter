defmodule Holter.Integrations.Engine.ActionRunnerTest do
  use ExUnit.Case, async: true

  import Mox

  alias Holter.Integrations.Engine.ActionRunner
  alias Holter.Integrations.ProviderMock
  alias Holter.Integrations.Request

  setup :verify_on_exit!

  defp ok_request,
    do: %Request{method: :post, url: "https://provider.test/mutate", headers: [], body: %{}}

  describe "run/3" do
    test "returns :ok without asking the provider to encode when there are no targets" do
      assert :ok = ActionRunner.run(ProviderMock, %{}, %{targets: []})
    end

    test "skips targets that carry no action" do
      payload = %{targets: [%{"type" => "channel", "id" => "ch-1"}]}

      assert :ok = ActionRunner.run(ProviderMock, %{}, payload)
    end

    test "skips targets whose action the provider does not support" do
      expect(ProviderMock, :encode, fn "post_message", _target, _integration -> :unsupported end)

      payload = %{targets: [%{"action" => "post_message", "id" => "x"}]}

      assert :ok = ActionRunner.run(ProviderMock, %{}, payload)
    end

    test "executes the encoded request on success" do
      expect(ProviderMock, :encode, fn "pause_campaign", %{"id" => "camp-1"}, _integration ->
        {:ok, ok_request()}
      end)

      expect(Holter.Integrations.HttpClientMock, :post, fn _url, _body, _headers ->
        {:ok, %{status: 200, body: %{}}}
      end)

      payload = %{targets: [%{"action" => "pause_campaign", "id" => "camp-1"}]}

      assert :ok = ActionRunner.run(ProviderMock, %{}, payload)
    end

    test "halts with the encoder error when the action cannot be encoded" do
      expect(ProviderMock, :encode, fn _action, _target, _integration ->
        {:error, :invalid_target_id}
      end)

      payload = %{targets: [%{"action" => "pause_campaign", "id" => "bad"}]}

      assert {:error, :invalid_target_id} = ActionRunner.run(ProviderMock, %{}, payload)
    end

    test "halts on the first transport failure and skips remaining targets" do
      expect(ProviderMock, :encode, 1, fn _action, _target, _integration ->
        {:ok, ok_request()}
      end)

      expect(Holter.Integrations.HttpClientMock, :post, 1, fn _url, _body, _headers ->
        {:error, :timeout}
      end)

      payload = %{
        targets: [
          %{"action" => "pause_campaign", "id" => "camp-1"},
          %{"action" => "pause_campaign", "id" => "camp-2"}
        ]
      }

      assert {:error, :timeout} = ActionRunner.run(ProviderMock, %{}, payload)
    end
  end

  describe "run/3 — body serialization" do
    test "form-urlencodes the body when the request declares a form content type" do
      request = %Request{
        method: :post,
        url: "https://provider.test/mutate",
        headers: [{"content-type", "application/x-www-form-urlencoded"}],
        body: %{"status" => "PAUSED", "access_token" => "tok"}
      }

      expect(ProviderMock, :encode, fn _action, _target, _integration -> {:ok, request} end)

      test_pid = self()

      expect(Holter.Integrations.HttpClientMock, :post, fn _url, body, _headers ->
        send(test_pid, {:decoded, URI.decode_query(body)})
        {:ok, %{status: 200, body: %{}}}
      end)

      ActionRunner.run(ProviderMock, %{}, %{
        targets: [%{"action" => "pause_campaign", "id" => "1"}]
      })

      assert_received {:decoded, %{"status" => "PAUSED", "access_token" => "tok"}}
    end

    test "json-encodes the body by default when no form content type is declared" do
      request = %Request{
        method: :post,
        url: "https://provider.test/mutate",
        headers: [{"content-type", "application/json"}],
        body: %{"operations" => []}
      }

      expect(ProviderMock, :encode, fn _action, _target, _integration -> {:ok, request} end)

      test_pid = self()

      expect(Holter.Integrations.HttpClientMock, :post, fn _url, body, _headers ->
        send(test_pid, {:decoded, Jason.decode!(body)})
        {:ok, %{status: 200, body: %{}}}
      end)

      ActionRunner.run(ProviderMock, %{}, %{
        targets: [%{"action" => "pause_campaign", "id" => "1"}]
      })

      assert_received {:decoded, %{"operations" => []}}
    end
  end
end
