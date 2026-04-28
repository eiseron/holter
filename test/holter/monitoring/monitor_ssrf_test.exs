defmodule Holter.Monitoring.MonitorSsrfTest do
  use ExUnit.Case, async: true

  alias Holter.Monitoring.Monitor

  defp monitor_changeset(url) do
    Monitor.changeset(%Monitor{}, %{
      url: url,
      method: :get,
      timeout_seconds: 30,
      workspace_id: Ecto.UUID.generate()
    })
  end

  defp ssrf_error?(changeset) do
    Enum.any?(changeset.errors, fn
      {:url, {"is a restricted internal address", _}} -> true
      _ -> false
    end)
  end

  describe "monitor URL — gaps closed by Holter.Network.Guard unification" do
    test "rejects IPv4-mapped IPv6 ::ffff:127.0.0.1" do
      assert ssrf_error?(monitor_changeset("http://[::ffff:127.0.0.1]/probe"))
    end

    test "rejects IPv4-mapped IPv6 ::ffff:10.0.0.1" do
      assert ssrf_error?(monitor_changeset("http://[::ffff:10.0.0.1]/probe"))
    end

    test "rejects IPv6 ULA fc00::/7" do
      assert ssrf_error?(monitor_changeset("http://[fc00::1]/probe"))
    end

    test "rejects IPv6 ULA fd00::/8" do
      assert ssrf_error?(monitor_changeset("http://[fd12:3456:789a::1]/probe"))
    end

    test "rejects IPv6 link-local fe80::/10" do
      assert ssrf_error?(monitor_changeset("http://[fe80::1]/probe"))
    end
  end

  describe "monitor URL — pre-existing protections still hold" do
    test "rejects IPv4 loopback 127.0.0.1" do
      assert ssrf_error?(monitor_changeset("http://127.0.0.1/probe"))
    end

    test "rejects RFC1918 192.168.1.1" do
      assert ssrf_error?(monitor_changeset("http://192.168.1.1/probe"))
    end

    test "rejects hex-encoded IPv4 0x7f000001" do
      assert ssrf_error?(monitor_changeset("http://0x7f000001/probe"))
    end

    test "rejects IPv6 loopback ::1" do
      assert ssrf_error?(monitor_changeset("http://[::1]/probe"))
    end
  end

  describe "monitor URL — public addresses accepted" do
    test "accepts a public domain" do
      changeset = monitor_changeset("https://example.com/probe")
      refute ssrf_error?(changeset)
    end

    test "accepts a public IPv6 address" do
      changeset = monitor_changeset("http://[2606:4700:4700::1111]/probe")
      refute ssrf_error?(changeset)
    end
  end
end
