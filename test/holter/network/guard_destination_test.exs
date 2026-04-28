defmodule Holter.Network.GuardDestinationTest do
  use ExUnit.Case, async: false

  import Mox

  alias Holter.Network.Guard
  alias Holter.Network.ResolverMock

  setup :verify_on_exit!

  setup do
    on_exit(fn -> Application.put_env(:holter, :network, []) end)
    :ok
  end

  describe "validate_destination/1 — happy path" do
    test "returns the resolved IP when DNS yields a single public address" do
      expect(ResolverMock, :getaddrs, fn ~c"public.example.com", :inet ->
        {:ok, [{1, 2, 3, 4}]}
      end)

      assert Guard.validate_destination("https://public.example.com/hook") == {:ok, "1.2.3.4"}
    end

    test "returns the first resolved IP when DNS yields multiple public addresses" do
      expect(ResolverMock, :getaddrs, fn _, :inet ->
        {:ok, [{1, 2, 3, 4}, {5, 6, 7, 8}]}
      end)

      assert {:ok, "1.2.3.4"} = Guard.validate_destination("https://public.example.com/hook")
    end
  end

  describe "validate_destination/1 — DNS-rebinding rejections" do
    test "rejects when DNS resolves to a private IPv4" do
      expect(ResolverMock, :getaddrs, fn _, :inet ->
        {:ok, [{10, 0, 0, 1}]}
      end)

      assert Guard.validate_destination("https://rebind.example.com/hook") ==
               {:error, :private_host}
    end

    test "rejects when DNS resolves to loopback" do
      expect(ResolverMock, :getaddrs, fn _, :inet ->
        {:ok, [{127, 0, 0, 1}]}
      end)

      assert Guard.validate_destination("https://localhost-rebind.example.com/hook") ==
               {:error, :private_host}
    end

    test "rejects when DNS yields a mix of public and private addresses (any-restricted)" do
      expect(ResolverMock, :getaddrs, fn _, :inet ->
        {:ok, [{1, 2, 3, 4}, {10, 0, 0, 1}]}
      end)

      assert Guard.validate_destination("https://mixed.example.com/hook") ==
               {:error, :private_host}
    end
  end

  describe "validate_destination/1 — DNS failures" do
    test "returns :unresolved when DNS lookup fails with :nxdomain" do
      expect(ResolverMock, :getaddrs, fn _, :inet ->
        {:error, :nxdomain}
      end)

      assert Guard.validate_destination("https://nope.example.invalid/hook") ==
               {:error, :unresolved}
    end

    test "returns :unresolved on transport errors (:timeout)" do
      expect(ResolverMock, :getaddrs, fn _, :inet ->
        {:error, :timeout}
      end)

      assert Guard.validate_destination("https://slow.example.com/hook") ==
               {:error, :unresolved}
    end
  end

  describe "validate_destination/1 — trusted hosts allowlist" do
    test "allows a private resolved IP when the IP is in the allowlist" do
      Application.put_env(:holter, :network, trusted_hosts: ["10.0.0.1"])

      expect(ResolverMock, :getaddrs, fn _, :inet -> {:ok, [{10, 0, 0, 1}]} end)

      assert Guard.validate_destination("https://internal.example.com/hook") ==
               {:ok, "10.0.0.1"}
    end

    test "falls back to the original host when DNS fails for an allowlisted host" do
      Application.put_env(:holter, :network, trusted_hosts: ["internal.local"])

      expect(ResolverMock, :getaddrs, fn _, :inet -> {:error, :nxdomain} end)

      assert Guard.validate_destination("https://internal.local/hook") ==
               {:ok, "internal.local"}
    end

    test "non-allowlisted host whose DNS fails returns :unresolved" do
      expect(ResolverMock, :getaddrs, fn _, :inet -> {:error, :nxdomain} end)

      assert Guard.validate_destination("https://nope.example.invalid/hook") ==
               {:error, :unresolved}
    end

    test "allowlist does not bypass static URL rejections" do
      Application.put_env(:holter, :network, trusted_hosts: ["internal.local"])

      assert Guard.validate_destination("ftp://internal.local/hook") == {:error, :invalid_scheme}
    end
  end

  describe "validate_destination/1 — static URL rejections" do
    test "bubbles up :control_chars without calling the resolver" do
      expect(ResolverMock, :getaddrs, 0, fn _, _ -> flunk("resolver should not be called") end)

      assert Guard.validate_destination("https://example.com\r\n/hook") ==
               {:error, :control_chars}
    end

    test "bubbles up :credentials without calling the resolver" do
      expect(ResolverMock, :getaddrs, 0, fn _, _ -> flunk("resolver should not be called") end)

      assert Guard.validate_destination("https://user:pass@example.com/hook") ==
               {:error, :credentials}
    end

    test "bubbles up :invalid_scheme without calling the resolver" do
      expect(ResolverMock, :getaddrs, 0, fn _, _ -> flunk("resolver should not be called") end)

      assert Guard.validate_destination("ftp://example.com/hook") == {:error, :invalid_scheme}
    end

    test "rejects literal-IP URLs without calling the resolver" do
      expect(ResolverMock, :getaddrs, 0, fn _, _ -> flunk("resolver should not be called") end)

      assert Guard.validate_destination("http://10.0.0.1/hook") == {:error, :private_host}
    end

    test "rejects non-binary input as :invalid_url" do
      assert Guard.validate_destination(nil) == {:error, :invalid_url}
    end
  end
end
