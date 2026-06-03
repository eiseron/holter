defmodule HolterWeb.Plugs.IntegrationWebhookSignaturePlugTest do
  use HolterWeb.ConnCase, async: true

  alias HolterWeb.Plugs.IntegrationWebhookSignaturePlug

  defmodule StubProviderNoWebhook do
    @moduledoc false
    @behaviour Holter.Integrations.Provider

    def display_name, do: "Stub"
    def oauth_url(_workspace_id, _state), do: {:ok, "https://example.com"}
    def handle_callback(_params, _state), do: {:ok, %{}}
    def refresh(_credentials), do: {:ok, %{}}
    def encode(_action, _target, _integration), do: :unsupported
    def revoke(_credentials), do: :ok
    def supported_actions, do: []
    def supported_events, do: []
  end

  defmodule StubProviderOk do
    @moduledoc false
    @behaviour Holter.Integrations.Provider

    def display_name, do: "OkStub"
    def oauth_url(_w, _s), do: {:ok, ""}
    def handle_callback(_p, _s), do: {:ok, %{}}
    def refresh(_c), do: {:ok, %{}}
    def encode(_action, _target, _integration), do: :unsupported
    def revoke(_c), do: :ok
    def supported_actions, do: []
    def supported_events, do: []
    def validate_webhook_signature(_raw, _headers, _secret), do: :ok
  end

  defmodule StubProviderTimestampExpired do
    @moduledoc false
    @behaviour Holter.Integrations.Provider

    def display_name, do: "TStub"
    def oauth_url(_w, _s), do: {:ok, ""}
    def handle_callback(_p, _s), do: {:ok, %{}}
    def refresh(_c), do: {:ok, %{}}
    def encode(_action, _target, _integration), do: :unsupported
    def revoke(_c), do: :ok
    def supported_actions, do: []
    def supported_events, do: []
    def validate_webhook_signature(_raw, _headers, _secret), do: {:error, :timestamp_expired}
  end

  defmodule StubProviderInvalidSig do
    @moduledoc false
    @behaviour Holter.Integrations.Provider

    def display_name, do: "IStub"
    def oauth_url(_w, _s), do: {:ok, ""}
    def handle_callback(_p, _s), do: {:ok, %{}}
    def refresh(_c), do: {:ok, %{}}
    def encode(_action, _target, _integration), do: :unsupported
    def revoke(_c), do: :ok
    def supported_actions, do: []
    def supported_events, do: []
    def validate_webhook_signature(_raw, _headers, _secret), do: {:error, :invalid_signature}
  end

  describe "call/2 with no provider param" do
    test "passes through when provider param is absent", %{conn: conn} do
      result_conn =
        conn
        |> Map.put(:params, %{})
        |> IntegrationWebhookSignaturePlug.call([])

      refute result_conn.halted
    end
  end

  describe "call/2 with unknown provider" do
    test "passes through when provider is not registered", %{conn: conn} do
      result_conn =
        conn
        |> Map.put(:params, %{"provider" => "google_ads"})
        |> IntegrationWebhookSignaturePlug.call([])

      refute result_conn.halted
    end
  end

  describe "call/2 with invalid atom provider" do
    test "passes through when provider string maps to no existing atom", %{conn: conn} do
      result_conn =
        conn
        |> Map.put(:params, %{"provider" => "totally_unknown_provider_xyz"})
        |> IntegrationWebhookSignaturePlug.call([])

      refute result_conn.halted
    end
  end

  describe "call/2 with registered provider that does not implement validate_webhook_signature" do
    setup do
      on_exit(fn -> Application.put_env(:holter, :integration_providers, %{}) end)

      Application.put_env(:holter, :integration_providers, %{
        stub_no_webhook: StubProviderNoWebhook
      })

      :ok
    end

    test "passes through without validating signature", %{conn: conn} do
      result_conn =
        conn
        |> Map.put(:params, %{"provider" => "stub_no_webhook"})
        |> IntegrationWebhookSignaturePlug.call([])

      refute result_conn.halted
    end
  end

  describe "call/2 with provider returning :ok signature" do
    setup do
      on_exit(fn -> Application.put_env(:holter, :integration_providers, %{}) end)

      Application.put_env(:holter, :integration_providers, %{stub_ok: StubProviderOk})

      :ok
    end

    test "marks the request verified when signature validation succeeds", %{conn: conn} do
      result_conn =
        conn
        |> Map.put(:params, %{"provider" => "stub_ok"})
        |> Plug.Conn.put_private(:webhook_secret, "shh")
        |> IntegrationWebhookSignaturePlug.call([])

      assert result_conn.private[:webhook_verified] == true
    end
  end

  describe "call/2 with provider returning :timestamp_expired" do
    setup do
      on_exit(fn -> Application.put_env(:holter, :integration_providers, %{}) end)

      Application.put_env(:holter, :integration_providers, %{
        stub_ts: StubProviderTimestampExpired
      })

      :ok
    end

    test "halts with 401 when timestamp is expired", %{conn: conn} do
      result_conn =
        conn
        |> Map.put(:params, %{"provider" => "stub_ts"})
        |> Plug.Conn.put_private(:webhook_secret, "shh")
        |> IntegrationWebhookSignaturePlug.call([])

      assert result_conn.halted
    end
  end

  describe "call/2 with provider returning invalid signature" do
    setup do
      on_exit(fn -> Application.put_env(:holter, :integration_providers, %{}) end)

      Application.put_env(:holter, :integration_providers, %{stub_inv: StubProviderInvalidSig})

      :ok
    end

    test "halts with 401 when signature is invalid", %{conn: conn} do
      result_conn =
        conn
        |> Map.put(:params, %{"provider" => "stub_inv"})
        |> Plug.Conn.put_private(:webhook_secret, "shh")
        |> IntegrationWebhookSignaturePlug.call([])

      assert result_conn.halted
    end
  end

  describe "call/2 when no webhook secret is configured" do
    setup do
      on_exit(fn -> Application.put_env(:holter, :integration_providers, %{}) end)

      Application.put_env(:holter, :integration_providers, %{stub_ok: StubProviderOk})

      :ok
    end

    test "halts with 401 when secret is missing from conn private", %{conn: conn} do
      result_conn =
        conn
        |> Map.put(:params, %{"provider" => "stub_ok"})
        |> IntegrationWebhookSignaturePlug.call([])

      assert result_conn.halted
    end
  end
end
