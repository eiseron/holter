defmodule Holter.Network.GuardTest do
  use ExUnit.Case, async: false

  alias Holter.Network.Guard

  describe "restricted_url?/1 — string-level rejections" do
    test "rejects URL with embedded space" do
      assert Guard.restricted_url?("http://example.com /hook") == {:error, :control_chars}
    end

    test "rejects URL with tab" do
      assert Guard.restricted_url?("http://example.com\t/hook") == {:error, :control_chars}
    end

    test "rejects URL with CR" do
      assert Guard.restricted_url?("http://example.com\r/hook") == {:error, :control_chars}
    end

    test "rejects URL with LF (header-injection shape)" do
      assert Guard.restricted_url?("http://example.com\n/hook") == {:error, :control_chars}
    end

    test "rejects URL with userinfo (basic auth)" do
      assert Guard.restricted_url?("http://user:pass@example.com/hook") ==
               {:error, :credentials}
    end

    test "rejects URL with userinfo (no password)" do
      assert Guard.restricted_url?("http://attacker@example.com/hook") ==
               {:error, :credentials}
    end

    test "rejects URL with non-http(s) scheme" do
      assert Guard.restricted_url?("ftp://example.com/hook") == {:error, :invalid_scheme}
    end

    test "rejects URL with no host" do
      assert Guard.restricted_url?("http:///hook") == {:error, :invalid_scheme}
    end

    test "rejects non-string input" do
      assert Guard.restricted_url?(nil) == {:error, :invalid_scheme}
    end
  end

  describe "restricted_url?/1 — host-level rejections" do
    test "rejects http://localhost" do
      assert Guard.restricted_url?("http://localhost/hook") == {:error, :private_host}
    end

    test "rejects http://127.0.0.1" do
      assert Guard.restricted_url?("http://127.0.0.1/hook") == {:error, :private_host}
    end

    test "rejects http://10.0.0.1 (RFC1918)" do
      assert Guard.restricted_url?("http://10.0.0.1/hook") == {:error, :private_host}
    end

    test "rejects http://192.168.1.1 (RFC1918)" do
      assert Guard.restricted_url?("http://192.168.1.1/hook") == {:error, :private_host}
    end

    test "rejects http://172.16.0.1 (RFC1918 lower bound)" do
      assert Guard.restricted_url?("http://172.16.0.1/hook") == {:error, :private_host}
    end

    test "rejects http://172.31.255.255 (RFC1918 upper bound)" do
      assert Guard.restricted_url?("http://172.31.255.255/hook") == {:error, :private_host}
    end

    test "rejects http://169.254.169.254 (cloud metadata)" do
      assert Guard.restricted_url?("http://169.254.169.254/latest/meta-data") ==
               {:error, :private_host}
    end

    test "rejects http://0.0.0.0" do
      assert Guard.restricted_url?("http://0.0.0.0/hook") == {:error, :private_host}
    end

    test "rejects bracketed IPv6 loopback http://[::1]" do
      assert Guard.restricted_url?("http://[::1]/hook") == {:error, :private_host}
    end

    test "rejects bracketed IPv6 unspecified http://[::]" do
      assert Guard.restricted_url?("http://[::]/hook") == {:error, :private_host}
    end

    test "rejects IPv4-mapped IPv6 ::ffff:127.0.0.1" do
      assert Guard.restricted_url?("http://[::ffff:127.0.0.1]/hook") ==
               {:error, :private_host}
    end

    test "rejects IPv4-mapped IPv6 ::ffff:10.0.0.1 (private RFC1918)" do
      assert Guard.restricted_url?("http://[::ffff:10.0.0.1]/hook") ==
               {:error, :private_host}
    end

    test "rejects IPv6 ULA fc00::/7" do
      assert Guard.restricted_url?("http://[fc00::1]/hook") == {:error, :private_host}
    end

    test "rejects IPv6 ULA fd00::/8 (still under fc00::/7)" do
      assert Guard.restricted_url?("http://[fd12:3456:789a::1]/hook") ==
               {:error, :private_host}
    end

    test "rejects IPv6 link-local fe80::/10" do
      assert Guard.restricted_url?("http://[fe80::1]/hook") == {:error, :private_host}
    end

    test "rejects hex-encoded IPv4 (0x7f000001)" do
      assert Guard.restricted_url?("http://0x7f000001/hook") == {:error, :private_host}
    end

    test "rejects decimal-encoded IPv4 (2130706433)" do
      assert Guard.restricted_url?("http://2130706433/hook") == {:error, :private_host}
    end

    test "rejects two-part short-form IPv4 (127.1)" do
      assert Guard.restricted_url?("http://127.1/hook") == {:error, :private_host}
    end

    test "rejects single-token host without a dot (intranet)" do
      assert Guard.restricted_url?("http://intranet/hook") == {:error, :private_host}
    end
  end

  describe "restricted_url?/1 — public URLs accepted" do
    test "accepts public https URL" do
      assert Guard.restricted_url?("https://example.com/hook") == :ok
    end

    test "accepts public http URL" do
      assert Guard.restricted_url?("http://hooks.example.com/notify") == :ok
    end

    test "accepts public URL with port" do
      assert Guard.restricted_url?("https://api.example.com:8443/events") == :ok
    end

    test "accepts public IPv6 (Cloudflare DNS)" do
      assert Guard.restricted_url?("http://[2606:4700:4700::1111]/hook") == :ok
    end

    test "accepts 172.15.255.255 (just below RFC1918 range)" do
      assert Guard.restricted_url?("http://172.15.255.255/hook") == :ok
    end

    test "accepts 172.32.0.1 (just above RFC1918 range)" do
      assert Guard.restricted_url?("http://172.32.0.1/hook") == :ok
    end
  end

  describe "restricted_ip?/1" do
    test "returns false for nil" do
      refute Guard.restricted_ip?(nil)
    end

    test "returns false for non-IP string" do
      refute Guard.restricted_ip?("not-an-ip")
    end

    test "returns true for IPv4 loopback" do
      assert Guard.restricted_ip?("127.0.0.1")
    end

    test "returns true for RFC1918 10.x" do
      assert Guard.restricted_ip?("10.0.0.1")
    end

    test "returns true for RFC1918 172.16.x" do
      assert Guard.restricted_ip?("172.16.0.1")
    end

    test "returns false for 172.15.x (below RFC range)" do
      refute Guard.restricted_ip?("172.15.0.1")
    end

    test "returns false for 172.32.x (above RFC range)" do
      refute Guard.restricted_ip?("172.32.0.1")
    end

    test "returns true for RFC1918 192.168.x" do
      assert Guard.restricted_ip?("192.168.1.1")
    end

    test "returns true for link-local 169.254.x" do
      assert Guard.restricted_ip?("169.254.1.1")
    end

    test "returns true for 0.0.0.0" do
      assert Guard.restricted_ip?("0.0.0.0")
    end

    test "returns true for IPv6 loopback ::1" do
      assert Guard.restricted_ip?("::1")
    end

    test "returns true for IPv6 ULA fc00::1" do
      assert Guard.restricted_ip?("fc00::1")
    end

    test "returns true for IPv6 link-local fe80::1" do
      assert Guard.restricted_ip?("fe80::1")
    end

    test "returns true for IPv4-mapped IPv6 ::ffff:127.0.0.1" do
      assert Guard.restricted_ip?("::ffff:127.0.0.1")
    end

    test "returns false for public IP 8.8.8.8" do
      refute Guard.restricted_ip?("8.8.8.8")
    end

    test "returns false for public IPv6 2606:4700:4700::1111" do
      refute Guard.restricted_ip?("2606:4700:4700::1111")
    end
  end

  describe "restricted_host?/1" do
    test "returns true for nil" do
      assert Guard.restricted_host?(nil)
    end

    test "returns true for localhost" do
      assert Guard.restricted_host?("localhost")
    end

    test "is case-insensitive (LOCALHOST)" do
      assert Guard.restricted_host?("LOCALHOST")
    end

    test "returns true for bracketed [::1]" do
      assert Guard.restricted_host?("[::1]")
    end

    test "returns true for single-token host" do
      assert Guard.restricted_host?("metadata")
    end

    test "returns true for hex-encoded IP host" do
      assert Guard.restricted_host?("0x7f000001")
    end

    test "returns true for short-form IP host 127.1" do
      assert Guard.restricted_host?("127.1")
    end

    test "returns false for example.com" do
      refute Guard.restricted_host?("example.com")
    end
  end

  describe "private_network_address?/1 — IPv4" do
    test "{127, 0, 0, 1} loopback" do
      assert Guard.private_network_address?({127, 0, 0, 1})
    end

    test "{10, 0, 0, 1} RFC1918" do
      assert Guard.private_network_address?({10, 0, 0, 1})
    end

    test "{172, 16, 0, 1} RFC1918 lower bound" do
      assert Guard.private_network_address?({172, 16, 0, 1})
    end

    test "{172, 31, 255, 255} RFC1918 upper bound" do
      assert Guard.private_network_address?({172, 31, 255, 255})
    end

    test "{172, 15, 0, 1} below RFC range" do
      refute Guard.private_network_address?({172, 15, 0, 1})
    end

    test "{172, 32, 0, 1} above RFC range" do
      refute Guard.private_network_address?({172, 32, 0, 1})
    end

    test "{192, 168, 1, 1} RFC1918" do
      assert Guard.private_network_address?({192, 168, 1, 1})
    end

    test "{169, 254, 1, 1} link-local" do
      assert Guard.private_network_address?({169, 254, 1, 1})
    end

    test "{0, 0, 0, 0} unspecified" do
      assert Guard.private_network_address?({0, 0, 0, 0})
    end

    test "{0, 1, 2, 3} (whole 0.0.0.0/8)" do
      assert Guard.private_network_address?({0, 1, 2, 3})
    end

    test "{8, 8, 8, 8} public" do
      refute Guard.private_network_address?({8, 8, 8, 8})
    end
  end

  describe "private_network_address?/1 — IPv6" do
    test "loopback ::1" do
      assert Guard.private_network_address?({0, 0, 0, 0, 0, 0, 0, 1})
    end

    test "unspecified ::" do
      assert Guard.private_network_address?({0, 0, 0, 0, 0, 0, 0, 0})
    end

    test "ULA fc00::1" do
      assert Guard.private_network_address?({0xFC00, 0, 0, 0, 0, 0, 0, 1})
    end

    test "ULA fd12:3456:789a::1" do
      assert Guard.private_network_address?({0xFD12, 0x3456, 0x789A, 0, 0, 0, 0, 1})
    end

    test "link-local fe80::1" do
      assert Guard.private_network_address?({0xFE80, 0, 0, 0, 0, 0, 0, 1})
    end

    test "IPv4-mapped ::ffff:127.0.0.1 (recurses into IPv4 loopback)" do
      assert Guard.private_network_address?({0, 0, 0, 0, 0, 0xFFFF, 0x7F00, 0x0001})
    end

    test "IPv4-mapped ::ffff:8.8.8.8 (public IPv4 — not private)" do
      refute Guard.private_network_address?({0, 0, 0, 0, 0, 0xFFFF, 0x0808, 0x0808})
    end

    test "public IPv6 2606:4700:4700::1111" do
      refute Guard.private_network_address?({0x2606, 0x4700, 0x4700, 0, 0, 0, 0, 0x1111})
    end
  end

  describe "encoded_ip?/1" do
    test "hex-encoded 0x7f000001" do
      assert Guard.encoded_ip?("0x7f000001")
    end

    test "decimal integer 2130706433" do
      assert Guard.encoded_ip?("2130706433")
    end

    test "two-part short form 127.0" do
      assert Guard.encoded_ip?("127.0")
    end

    test "three-part short form 10.0.1" do
      assert Guard.encoded_ip?("10.0.1")
    end

    test "rejects normal four-part 127.0.0.1" do
      refute Guard.encoded_ip?("127.0.0.1")
    end

    test "rejects domain example.com" do
      refute Guard.encoded_ip?("example.com")
    end
  end

  describe "single_token_host?/1" do
    test "true for token without dot" do
      assert Guard.single_token_host?("metadata")
    end

    test "false for FQDN" do
      refute Guard.single_token_host?("example.com")
    end
  end

  describe "trusted hosts allowlist" do
    setup do
      previous = Application.get_env(:holter, :network, [])

      Application.put_env(
        :holter,
        :network,
        Keyword.put(previous, :trusted_hosts, ["localhost", "127.0.0.1"])
      )

      on_exit(fn -> Application.put_env(:holter, :network, previous) end)
    end

    test "restricted_host? returns false for allowlisted localhost" do
      refute Guard.restricted_host?("localhost")
    end

    test "restricted_host? still blocks non-allowlisted private host" do
      assert Guard.restricted_host?("192.168.1.1")
    end

    test "restricted_ip? returns false for allowlisted IP" do
      refute Guard.restricted_ip?("127.0.0.1")
    end

    test "restricted_ip? still blocks non-allowlisted private IP" do
      assert Guard.restricted_ip?("10.0.0.1")
    end
  end
end
