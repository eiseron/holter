defmodule Holter.Monitoring.Engine.NetworkGuardTest do
  use ExUnit.Case, async: true

  alias Holter.Monitoring.Engine.NetworkGuard

  describe "restricted_ip?/1" do
    test "returns false for nil" do
      refute NetworkGuard.restricted_ip?(nil)
    end

    test "returns true for loopback 127.0.0.1" do
      assert NetworkGuard.restricted_ip?("127.0.0.1")
    end

    test "returns true for 10.x private IP" do
      assert NetworkGuard.restricted_ip?("10.0.0.1")
    end

    test "returns true for 172.16.x private IP" do
      assert NetworkGuard.restricted_ip?("172.16.0.1")
    end

    test "returns true for 172.31.x private IP" do
      assert NetworkGuard.restricted_ip?("172.31.255.255")
    end

    test "returns false for 172.15.x (below RFC private range)" do
      refute NetworkGuard.restricted_ip?("172.15.0.1")
    end

    test "returns false for 172.32.x (above RFC private range)" do
      refute NetworkGuard.restricted_ip?("172.32.0.1")
    end

    test "returns true for 192.168.x private IP" do
      assert NetworkGuard.restricted_ip?("192.168.1.1")
    end

    test "returns true for 169.254.x link-local IP" do
      assert NetworkGuard.restricted_ip?("169.254.1.1")
    end

    test "returns true for 0.0.0.0" do
      assert NetworkGuard.restricted_ip?("0.0.0.0")
    end

    test "returns false for public IP 8.8.8.8" do
      refute NetworkGuard.restricted_ip?("8.8.8.8")
    end

    test "returns false for non-parseable string" do
      refute NetworkGuard.restricted_ip?("not-an-ip")
    end
  end

  describe "restricted_host?/1" do
    test "returns true for nil" do
      assert NetworkGuard.restricted_host?(nil)
    end

    test "returns true for localhost" do
      assert NetworkGuard.restricted_host?("localhost")
    end

    test "returns true for 127.0.0.1" do
      assert NetworkGuard.restricted_host?("127.0.0.1")
    end

    test "returns true for IPv6 loopback ::1" do
      assert NetworkGuard.restricted_host?("::1")
    end

    test "returns true for bracketed IPv6 [::1]" do
      assert NetworkGuard.restricted_host?("[::1]")
    end

    test "returns true for 10.x private address" do
      assert NetworkGuard.restricted_host?("10.0.0.1")
    end

    test "returns true for 192.168.x address" do
      assert NetworkGuard.restricted_host?("192.168.1.1")
    end

    test "returns true for single-token host without dots" do
      assert NetworkGuard.restricted_host?("metadata")
    end

    test "returns false for public domain" do
      refute NetworkGuard.restricted_host?("example.com")
    end

    test "returns false for google.com" do
      refute NetworkGuard.restricted_host?("google.com")
    end

    test "is case-insensitive for LOCALHOST" do
      assert NetworkGuard.restricted_host?("LOCALHOST")
    end
  end

  describe "localhost?/1" do
    test "returns true for localhost" do
      assert NetworkGuard.localhost?("localhost")
    end

    test "returns true for 127.0.0.1" do
      assert NetworkGuard.localhost?("127.0.0.1")
    end

    test "returns true for ::1 IPv6 loopback" do
      assert NetworkGuard.localhost?("::1")
    end

    test "returns true for 0.0.0.0" do
      assert NetworkGuard.localhost?("0.0.0.0")
    end

    test "returns true for 127.10.0.1 (starts with 127.)" do
      assert NetworkGuard.localhost?("127.10.0.1")
    end

    test "returns true for ::ffff:127.0.0.1" do
      assert NetworkGuard.localhost?("::ffff:127.0.0.1")
    end

    test "returns false for example.com" do
      refute NetworkGuard.localhost?("example.com")
    end

    test "returns false for 128.0.0.1" do
      refute NetworkGuard.localhost?("128.0.0.1")
    end
  end

  describe "encoded_ip?/1" do
    test "returns true for hex-encoded IP 0x7f000001" do
      assert NetworkGuard.encoded_ip?("0x7f000001")
    end

    test "returns true for decimal integer IP 2130706433" do
      assert NetworkGuard.encoded_ip?("2130706433")
    end

    test "returns true for two-part short-form IP 127.0" do
      assert NetworkGuard.encoded_ip?("127.0")
    end

    test "returns true for three-part short-form IP 10.0.1" do
      assert NetworkGuard.encoded_ip?("10.0.1")
    end

    test "returns false for normal four-part IP 127.0.0.1" do
      refute NetworkGuard.encoded_ip?("127.0.0.1")
    end

    test "returns false for domain example.com" do
      refute NetworkGuard.encoded_ip?("example.com")
    end
  end

  describe "single_token_host?/1" do
    test "returns true for host with no dot" do
      assert NetworkGuard.single_token_host?("metadata")
    end

    test "returns true for localhost (no dot)" do
      assert NetworkGuard.single_token_host?("localhost")
    end

    test "returns false for host with dot" do
      refute NetworkGuard.single_token_host?("example.com")
    end
  end

  describe "private_network_address?/1" do
    test "returns true for {127, 0, 0, 1}" do
      assert NetworkGuard.private_network_address?({127, 0, 0, 1})
    end

    test "returns true for {10, 0, 0, 1}" do
      assert NetworkGuard.private_network_address?({10, 0, 0, 1})
    end

    test "returns true for {172, 16, 0, 1}" do
      assert NetworkGuard.private_network_address?({172, 16, 0, 1})
    end

    test "returns true for {172, 31, 255, 255}" do
      assert NetworkGuard.private_network_address?({172, 31, 255, 255})
    end

    test "returns false for {172, 15, 0, 1} (below RFC range)" do
      refute NetworkGuard.private_network_address?({172, 15, 0, 1})
    end

    test "returns false for {172, 32, 0, 1} (above RFC range)" do
      refute NetworkGuard.private_network_address?({172, 32, 0, 1})
    end

    test "returns true for {192, 168, 1, 1}" do
      assert NetworkGuard.private_network_address?({192, 168, 1, 1})
    end

    test "returns true for link-local {169, 254, 1, 1}" do
      assert NetworkGuard.private_network_address?({169, 254, 1, 1})
    end

    test "returns true for {0, 0, 0, 0}" do
      assert NetworkGuard.private_network_address?({0, 0, 0, 0})
    end

    test "returns false for public {8, 8, 8, 8}" do
      refute NetworkGuard.private_network_address?({8, 8, 8, 8})
    end

    test "returns true for IPv6 loopback tuple {0,0,0,0,0,0,0,1}" do
      assert NetworkGuard.private_network_address?({0, 0, 0, 0, 0, 0, 0, 1})
    end

    test "returns false for non-loopback IPv6 {0,0,0,0,0,0,0,0}" do
      refute NetworkGuard.private_network_address?({0, 0, 0, 0, 0, 0, 0, 0})
    end
  end
end
