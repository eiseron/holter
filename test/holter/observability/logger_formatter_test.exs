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

    scrubbed = LoggerFormatter.scrub_map_for_test(meta)
    %{scrubbed: scrubbed}
  end

  test "scrubs sensitive password at top level", %{scrubbed: scrubbed} do
    assert scrubbed.password == "[FILTERED]"
  end

  test "preserves user_id at top level", %{scrubbed: scrubbed} do
    assert scrubbed.user_id == "1"
  end

  test "scrubs sensitive password in nested params", %{scrubbed: scrubbed} do
    assert scrubbed.params["password"] == "[FILTERED]"
  end

  test "scrubs sensitive token in nested params", %{scrubbed: scrubbed} do
    assert scrubbed.params["token"] == "[FILTERED]"
  end

  test "preserves safe boolean in nested metadata", %{scrubbed: scrubbed} do
    assert scrubbed.safe == true
  end
end
