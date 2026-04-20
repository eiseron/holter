defmodule Holter.Monitoring.Engine.ResponseSanitizerTest do
  use ExUnit.Case, async: true

  alias Holter.Monitoring.Engine.ResponseSanitizer

  describe "filter_headers/1" do
    test "keeps server header" do
      result = ResponseSanitizer.filter_headers([{"server", "nginx"}])
      assert result["server"] == "nginx"
    end

    test "keeps content-type header" do
      result = ResponseSanitizer.filter_headers([{"content-type", "text/html"}])
      assert result["content-type"] == "text/html"
    end

    test "keeps cf-ray header" do
      result = ResponseSanitizer.filter_headers([{"cf-ray", "abc123"}])
      assert result["cf-ray"] == "abc123"
    end

    test "keeps cache-control header" do
      result = ResponseSanitizer.filter_headers([{"cache-control", "no-cache"}])
      assert result["cache-control"] == "no-cache"
    end

    test "drops unknown header x-custom" do
      result = ResponseSanitizer.filter_headers([{"x-custom", "value"}])
      refute Map.has_key?(result, "x-custom")
    end

    test "masks Bearer token found in header value" do
      result = ResponseSanitizer.filter_headers([{"server", "Bearer abc123"}])
      assert result["server"] == "Bearer [REDACTED]"
    end

    test "truncates header value longer than 1024 bytes" do
      long_val = String.duplicate("a", 2000)
      result = ResponseSanitizer.filter_headers([{"server", long_val}])
      assert byte_size(result["server"]) <= 1024
    end

    test "returns empty map for empty header list" do
      assert ResponseSanitizer.filter_headers([]) == %{}
    end
  end

  describe "clean_body_snippet/2" do
    test "strips HTML tags for text/html content type" do
      result = ResponseSanitizer.clean_body_snippet("<p>Hello</p>", "text/html")
      assert result == "Hello"
    end

    test "returns binary content notice for image/png" do
      result = ResponseSanitizer.clean_body_snippet(<<1, 2, 3>>, "image/png")
      assert result == "Binary content (skipped)"
    end

    test "truncates body to 512 chars" do
      long_body = String.duplicate("x", 1000)
      result = ResponseSanitizer.clean_body_snippet(long_body, "text/plain")
      assert String.length(result) <= 512
    end

    test "masks api_key secret in body snippet" do
      result = ResponseSanitizer.clean_body_snippet("api_key=supersecret", "text/plain")
      assert result == "api_key=[REDACTED]"
    end

    test "processes list content-type correctly" do
      result = ResponseSanitizer.clean_body_snippet("Hello", ["text/plain"])
      assert result == "Hello"
    end

    test "processes JSON content type as text" do
      result = ResponseSanitizer.clean_body_snippet(~s({"ok":true}), "application/json")
      assert is_binary(result)
    end
  end

  describe "mask_secrets/1" do
    test "redacts Bearer token" do
      assert ResponseSanitizer.mask_secrets("Bearer abc123") == "Bearer [REDACTED]"
    end

    test "redacts JWT token starting with eyJ" do
      jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.SIG"
      assert ResponseSanitizer.mask_secrets(jwt) == "[REDACTED]"
    end

    test "redacts api_key query parameter" do
      assert ResponseSanitizer.mask_secrets("api_key=secret123") == "api_key=[REDACTED]"
    end

    test "redacts password query parameter" do
      assert ResponseSanitizer.mask_secrets("password=hunter2") == "password=[REDACTED]"
    end

    test "redacts access_token query parameter" do
      assert ResponseSanitizer.mask_secrets("access_token=tok123") == "access_token=[REDACTED]"
    end

    test "redacts Stripe live secret key" do
      assert ResponseSanitizer.mask_secrets("sk_live_abcdefghijklmnopqrst") == "[REDACTED]"
    end

    test "redacts Stripe test publishable key" do
      assert ResponseSanitizer.mask_secrets("pk_test_abcdefghijklmnopqrst") == "[REDACTED]"
    end

    test "passes through non-string value unchanged" do
      assert ResponseSanitizer.mask_secrets(42) == 42
    end

    test "leaves clean string unchanged" do
      assert ResponseSanitizer.mask_secrets("hello world") == "hello world"
    end
  end

  describe "sanitize_for_db/1" do
    test "removes null bytes" do
      assert ResponseSanitizer.sanitize_for_db("hello\0world") == "helloworld"
    end

    test "replaces newline with space" do
      assert ResponseSanitizer.sanitize_for_db("hello\nworld") == "hello world"
    end

    test "replaces carriage return + newline with space" do
      assert ResponseSanitizer.sanitize_for_db("hello\r\nworld") == "hello world"
    end

    test "passes through non-string value unchanged" do
      assert ResponseSanitizer.sanitize_for_db(42) == 42
    end
  end

  describe "truncate_value/2" do
    test "truncates string longer than limit" do
      assert ResponseSanitizer.truncate_value("hello world", 5) == "hello"
    end

    test "returns string unchanged when within limit" do
      assert ResponseSanitizer.truncate_value("hi", 10) == "hi"
    end

    test "passes through non-string value unchanged" do
      assert ResponseSanitizer.truncate_value(42, 5) == 42
    end
  end

  describe "strip_html_tags/1" do
    test "removes script tag and its content" do
      result = ResponseSanitizer.strip_html_tags("<script>alert(1)</script>visible")
      refute String.contains?(result, "alert")
    end

    test "removes style tag and its content" do
      result = ResponseSanitizer.strip_html_tags("<style>body{color:red}</style>visible")
      refute String.contains?(result, "color")
    end

    test "returns text content from paragraph tags" do
      result = ResponseSanitizer.strip_html_tags("<p>Hello World</p>")
      assert String.contains?(result, "Hello World")
    end
  end

  describe "normalize_whitespace/1" do
    test "collapses multiple spaces into one" do
      assert ResponseSanitizer.normalize_whitespace("hello   world") == "hello world"
    end

    test "trims leading and trailing whitespace" do
      assert ResponseSanitizer.normalize_whitespace("  hello  ") == "hello"
    end

    test "collapses tab and newline into a single space" do
      assert ResponseSanitizer.normalize_whitespace("a\t\nb") == "a b"
    end
  end

  describe "ensure_utf8/1" do
    test "returns valid UTF-8 string unchanged" do
      assert ResponseSanitizer.ensure_utf8("hello") == "hello"
    end

    test "returns a binary result for invalid UTF-8 input" do
      result = ResponseSanitizer.ensure_utf8(<<195, 40>>)
      assert is_binary(result)
    end

    test "result is valid UTF-8 after sanitising invalid bytes" do
      result = ResponseSanitizer.ensure_utf8(<<195, 40>>)
      assert String.valid?(result)
    end
  end
end
