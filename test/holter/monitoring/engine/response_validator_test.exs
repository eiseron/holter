defmodule Holter.Monitoring.Engine.ResponseValidatorTest do
  use ExUnit.Case, async: true

  alias Holter.Monitoring.Engine.ResponseValidator

  describe "normalize_body/1" do
    test "returns binary body unchanged" do
      assert ResponseValidator.normalize_body("hello") == "hello"
    end

    test "encodes map body to JSON string" do
      assert ResponseValidator.normalize_body(%{"key" => "val"}) == ~s({"key":"val"})
    end

    test "returns empty string for nil body" do
      assert ResponseValidator.normalize_body(nil) == ""
    end
  end

  describe "html?/1" do
    test "returns true for text/html content type" do
      assert ResponseValidator.html?("text/html")
    end

    test "returns true for text/html in a list" do
      assert ResponseValidator.html?(["text/html; charset=utf-8"])
    end

    test "returns false for application/json" do
      refute ResponseValidator.html?("application/json")
    end

    test "returns false for nil" do
      refute ResponseValidator.html?(nil)
    end
  end

  describe "get_header/2" do
    test "returns value for matching header key" do
      assert ResponseValidator.get_header([{"content-type", "text/html"}], "content-type") ==
               "text/html"
    end

    test "returns nil when key is absent" do
      assert ResponseValidator.get_header([{"server", "nginx"}], "content-type") == nil
    end

    test "returns nil for empty header list" do
      assert ResponseValidator.get_header([], "content-type") == nil
    end
  end

  describe "validate_positive/2" do
    test "returns {true, []} when keywords list is nil" do
      assert ResponseValidator.validate_positive("body", nil) == {true, []}
    end

    test "returns {true, []} when keywords list is empty" do
      assert ResponseValidator.validate_positive("body", []) == {true, []}
    end

    test "returns {true, []} when keyword is present in body" do
      assert ResponseValidator.validate_positive("success page", ["success"]) == {true, []}
    end

    test "returns {false, [keyword]} when keyword is missing from body" do
      assert ResponseValidator.validate_positive("error page", ["success"]) ==
               {false, ["success"]}
    end

    test "includes only missing keywords in failure list" do
      assert ResponseValidator.validate_positive("hello", ["hello", "world"]) ==
               {false, ["world"]}
    end
  end

  describe "validate_negative/2" do
    test "returns {true, []} when keywords list is nil" do
      assert ResponseValidator.validate_negative("body", nil) == {true, []}
    end

    test "returns {true, []} when keywords list is empty" do
      assert ResponseValidator.validate_negative("body", []) == {true, []}
    end

    test "returns {true, []} when forbidden keyword is absent" do
      assert ResponseValidator.validate_negative("clean page", ["hacked"]) == {true, []}
    end

    test "returns {false, [keyword]} when forbidden keyword is found" do
      assert ResponseValidator.validate_negative("site hacked!", ["hacked"]) ==
               {false, ["hacked"]}
    end
  end

  describe "validate_keywords/2" do
    test "returns all-pass when no keywords configured" do
      monitor = %{keyword_positive: nil, keyword_negative: nil}
      assert ResponseValidator.validate_keywords("anything", monitor) == {true, true, [], []}
    end

    test "positive_ok is false when required keyword is missing" do
      monitor = %{keyword_positive: ["ok"], keyword_negative: nil}

      {positive_ok, _neg, _missing, _matched} =
        ResponseValidator.validate_keywords("fail", monitor)

      refute positive_ok
    end

    test "missing keywords list contains the absent keyword" do
      monitor = %{keyword_positive: ["ok"], keyword_negative: nil}
      {_pos, _neg, missing, _matched} = ResponseValidator.validate_keywords("fail", monitor)
      assert missing == ["ok"]
    end

    test "negative_ok is false when forbidden keyword found" do
      monitor = %{keyword_positive: nil, keyword_negative: ["bad"]}

      {_pos, negative_ok, _missing, _matched} =
        ResponseValidator.validate_keywords("bad content", monitor)

      refute negative_ok
    end

    test "matched list contains the forbidden keyword" do
      monitor = %{keyword_positive: nil, keyword_negative: ["bad"]}

      {_pos, _neg, _missing, matched} =
        ResponseValidator.validate_keywords("bad content", monitor)

      assert matched == ["bad"]
    end
  end

  describe "determine_check_status/3" do
    test "returns :down for status 404" do
      assert ResponseValidator.determine_check_status(404, true, true) == :down
    end

    test "returns :down for status 500" do
      assert ResponseValidator.determine_check_status(500, true, true) == :down
    end

    test "returns :down for status 199 (below 200)" do
      assert ResponseValidator.determine_check_status(199, true, true) == :down
    end

    test "returns :compromised when negative_ok is false on a 200" do
      assert ResponseValidator.determine_check_status(200, true, false) == :compromised
    end

    test "returns :down when positive_ok is false on a 200" do
      assert ResponseValidator.determine_check_status(200, false, true) == :down
    end

    test "returns :up when 200 and both keyword checks pass" do
      assert ResponseValidator.determine_check_status(200, true, true) == :up
    end

    test "returns :up for 201 with passing keywords" do
      assert ResponseValidator.determine_check_status(201, true, true) == :up
    end
  end

  describe "determine_downtime_error_msg/3" do
    test "returns HTTP error message for status 404" do
      assert ResponseValidator.determine_downtime_error_msg(404, true, []) == "HTTP Error: 404"
    end

    test "returns missing keywords message when positive_ok is false" do
      assert ResponseValidator.determine_downtime_error_msg(200, false, ["ok"]) ==
               ~s(Missing required keywords: "ok")
    end

    test "returns nil when check passed" do
      assert ResponseValidator.determine_downtime_error_msg(200, true, []) == nil
    end
  end

  describe "determine_defacement_error_msg/2" do
    test "returns found forbidden keywords message when negative_ok is false" do
      assert ResponseValidator.determine_defacement_error_msg(false, ["bad"]) ==
               ~s(Found forbidden keywords: "bad")
    end

    test "returns nil when negative_ok is true" do
      assert ResponseValidator.determine_defacement_error_msg(true, []) == nil
    end
  end

  describe "detect_defacement_indicators/1" do
    test "returns true when body contains hacked" do
      assert ResponseValidator.detect_defacement_indicators("this site was hacked!")
    end

    test "returns true when body contains defaced" do
      assert ResponseValidator.detect_defacement_indicators("site defaced by group")
    end

    test "returns true when body contains owned by" do
      assert ResponseValidator.detect_defacement_indicators("owned by hackers")
    end

    test "returns true when body contains you've been pwned" do
      assert ResponseValidator.detect_defacement_indicators("you've been pwned")
    end

    test "returns false for clean body" do
      refute ResponseValidator.detect_defacement_indicators("welcome to our website")
    end

    test "is case-insensitive for HACKED" do
      assert ResponseValidator.detect_defacement_indicators("HACKED")
    end
  end

  describe "prepare_search_body/2" do
    test "strips HTML tags when content type is text/html" do
      result = ResponseValidator.prepare_search_body("<p>Hello</p>", "text/html")
      assert String.contains?(result, "Hello")
    end

    test "returns body unchanged for non-HTML content type" do
      assert ResponseValidator.prepare_search_body("plain text", "text/plain") == "plain text"
    end
  end

  describe "binary_content?/1" do
    test "returns true for body containing a null byte" do
      assert ResponseValidator.binary_content?("\0hello")
    end

    test "returns true for invalid UTF-8 bytes" do
      assert ResponseValidator.binary_content?(<<195, 40>>)
    end

    test "returns false for a valid UTF-8 string" do
      refute ResponseValidator.binary_content?("hello world")
    end

    test "returns false for an empty string" do
      refute ResponseValidator.binary_content?("")
    end

    test "returns false for non-binary value" do
      refute ResponseValidator.binary_content?(nil)
    end
  end

  describe "validate_response/3 with liar content-type (binary body)" do
    defp binary_monitor(overrides \\ %{}) do
      Map.merge(
        %{
          health_status: :up,
          keyword_positive: ["expected"],
          keyword_negative: ["hacked"],
          body: nil,
          method: "get",
          headers: %{}
        },
        overrides
      )
    end

    defp binary_response(body, content_type) do
      %{
        status: 200,
        headers: [{"content-type", content_type}],
        body: body
      }
    end

    defp binary_meta, do: %{duration_ms: 50, ip: "1.2.3.4"}

    test "positive_ok is true for binary body declared as text/html (no false :down)" do
      monitor = binary_monitor()
      response = binary_response(<<0, 1, 2, 3>>, "text/html")
      result = ResponseValidator.validate_response(monitor, response, binary_meta())
      assert result.check_status == :up
    end

    test "negative_ok is true for binary body declared as text/html (no false :compromised)" do
      monitor = binary_monitor(%{keyword_positive: nil})
      response = binary_response(<<0, 1, 2, 3>>, "text/html")
      result = ResponseValidator.validate_response(monitor, response, binary_meta())
      refute result.check_status == :compromised
    end

    test "defacement_in_body is false for binary body" do
      monitor = binary_monitor(%{keyword_positive: nil, keyword_negative: nil})
      response = binary_response(<<0, 1, 2, 3>>, "text/html")
      result = ResponseValidator.validate_response(monitor, response, binary_meta())
      refute result.defacement_in_body
    end

    test "binary body declared as application/json skips keyword validation" do
      monitor = binary_monitor()
      response = binary_response(<<0, 1, 2>>, "application/json")
      result = ResponseValidator.validate_response(monitor, response, binary_meta())
      assert result.check_status == :up
    end

    test "null-byte body declared as text/plain skips keyword validation" do
      monitor = binary_monitor()
      response = binary_response("hello\0world", "text/plain")
      result = ResponseValidator.validate_response(monitor, response, binary_meta())
      assert result.check_status == :up
    end

    test "HTTP status still determines check_status for binary body (500 → :down)" do
      monitor = binary_monitor(%{keyword_positive: nil, keyword_negative: nil})
      response = binary_response(<<0, 1, 2>>, "text/html") |> Map.put(:status, 500)
      result = ResponseValidator.validate_response(monitor, response, binary_meta())
      assert result.check_status == :down
    end
  end

  describe "maybe_collect_evidence/3" do
    test "returns nil snippet when check status equals monitor health_status" do
      monitor = %{health_status: :up}
      response_data = %{headers: [], body: "ok", content_type: "text/plain"}
      {_headers, snippet} = ResponseValidator.maybe_collect_evidence(monitor, :up, response_data)
      assert is_nil(snippet)
    end

    test "returns nil headers when check status equals monitor health_status" do
      monitor = %{health_status: :up}
      response_data = %{headers: [], body: "ok", content_type: "text/plain"}
      {headers, _snippet} = ResponseValidator.maybe_collect_evidence(monitor, :up, response_data)
      assert is_nil(headers)
    end

    test "returns a map of headers when status changes" do
      monitor = %{health_status: :up}
      response_data = %{headers: [{"server", "nginx"}], body: "error", content_type: "text/plain"}

      {headers, _snippet} =
        ResponseValidator.maybe_collect_evidence(monitor, :down, response_data)

      assert is_map(headers)
    end

    test "returns a binary snippet when status changes" do
      monitor = %{health_status: :up}
      response_data = %{headers: [], body: "error body", content_type: "text/plain"}

      {_headers, snippet} =
        ResponseValidator.maybe_collect_evidence(monitor, :down, response_data)

      assert is_binary(snippet)
    end
  end
end
