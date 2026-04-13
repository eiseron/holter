defmodule Holter.Observability.LoggerFormatterTest do
  use ExUnit.Case, async: true
  alias Holter.Observability.LoggerFormatter

  setup do
    meta = %{
      password: "secret",
      user_id: "1",
      params: %{"password" => "secret", "token" => "abc"},
      safe: true
    }

    processed = LoggerFormatter.process_meta_for_test(meta)
    %{processed: processed}
  end

  test "scrubs sensitive password at top level", %{processed: p} do
    assert p.password == "[FILTERED]"
  end

  test "preserves user_id at top level", %{processed: p} do
    assert p.user_id == "1"
  end

  test "scrubs sensitive password in nested params", %{processed: p} do
    assert p.params["password"] == "[FILTERED]"
  end

  test "scrubs sensitive token in nested params", %{processed: p} do
    assert p.params["token"] == "[FILTERED]"
  end

  test "preserves safe data in nested metadata", %{processed: p} do
    assert p.params["safe"] == "data" || p.safe == true
  end

  test "includes node information", %{processed: p} do
    assert Map.has_key?(p, :node)
  end

  test "includes hostname information", %{processed: p} do
    assert Map.has_key?(p, :hostname)
  end

  test "includes otp version", %{processed: p} do
    assert Map.has_key?(p, :otp_version)
  end
end
