defmodule Holter.Delivery.WebhookSignatureTest do
  use ExUnit.Case, async: true

  alias Holter.Delivery.WebhookSignature

  @body ~s({"event":"monitor_down","monitor":{"url":"https://example.com"}})
  @token "test-token-fixed-for-determinism"
  @now ~U[2026-04-27 12:00:00Z]

  describe "build_signature_header/3" do
    test "uses the canonical header name x-holter-signature" do
      {name, _} = WebhookSignature.build_signature_header(@body, @token, @now)
      assert name == "x-holter-signature"
    end

    test "value follows the t=<unix>,v1=<hex> format" do
      {_, value} = WebhookSignature.build_signature_header(@body, @token, @now)
      assert value =~ ~r/^t=\d+,v1=[0-9a-f]{64}$/
    end

    test "the timestamp matches the supplied DateTime as a unix integer" do
      {_, value} = WebhookSignature.build_signature_header(@body, @token, @now)
      [t, _] = String.split(value, ",")
      assert t == "t=#{DateTime.to_unix(@now)}"
    end

    test "the same body, token and timestamp produce the same header" do
      first = WebhookSignature.build_signature_header(@body, @token, @now)
      second = WebhookSignature.build_signature_header(@body, @token, @now)
      assert first == second
    end

    test "changing the body changes the signature" do
      a = WebhookSignature.build_signature_header(@body, @token, @now)
      b = WebhookSignature.build_signature_header(@body <> " ", @token, @now)
      assert a != b
    end

    test "changing the token changes the signature" do
      a = WebhookSignature.build_signature_header(@body, @token, @now)
      b = WebhookSignature.build_signature_header(@body, "different-token", @now)
      assert a != b
    end

    test "changing the timestamp changes the signature" do
      a = WebhookSignature.build_signature_header(@body, @token, @now)
      b = WebhookSignature.build_signature_header(@body, @token, DateTime.add(@now, 1, :second))
      assert a != b
    end

    test "matches an externally computed HMAC of <unix>.<body>" do
      {_, value} = WebhookSignature.build_signature_header(@body, @token, @now)
      [_, "v1=" <> hex] = String.split(value, ",")
      unix = DateTime.to_unix(@now)

      expected =
        :crypto.mac(:hmac, :sha256, @token, "#{unix}.#{@body}")
        |> Base.encode16(case: :lower)

      assert hex == expected
    end
  end

  describe "compute_hmac/2" do
    test "produces a 64-character lowercase hex string" do
      hex = WebhookSignature.compute_hmac(@token, "1735689600.body")
      assert hex =~ ~r/^[0-9a-f]{64}$/
    end
  end
end
