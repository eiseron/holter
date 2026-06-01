defmodule Holter.Integrations.Engine.SignatureValidatorTest do
  use ExUnit.Case, async: true

  alias Holter.Integrations.Engine.SignatureValidator

  @secret "test_secret"
  @raw_body ~s({"event":"test"})

  defp sign_body(body, secret) do
    :crypto.mac(:hmac, :sha256, secret, body)
    |> Base.encode16(case: :lower)
  end

  defp unix_timestamp_str(offset_seconds \\ 0) do
    (System.system_time(:second) + offset_seconds) |> to_string()
  end

  describe "validate_hmac/2" do
    test "returns :ok when signature and timestamp are valid" do
      signature = sign_body(@raw_body, @secret)
      now = DateTime.utc_now()

      params = %{
        raw_body: @raw_body,
        signature: signature,
        secret: @secret,
        timestamp: unix_timestamp_str()
      }

      assert :ok = SignatureValidator.validate_hmac(params, now)
    end

    test "returns {:error, :invalid_signature} when signature is wrong" do
      now = DateTime.utc_now()

      params = %{
        raw_body: @raw_body,
        signature: "badsig",
        secret: @secret,
        timestamp: unix_timestamp_str()
      }

      assert {:error, :invalid_signature} = SignatureValidator.validate_hmac(params, now)
    end

    test "returns {:error, :timestamp_expired} when timestamp is too old" do
      signature = sign_body(@raw_body, @secret)
      now = DateTime.utc_now()

      params = %{
        raw_body: @raw_body,
        signature: signature,
        secret: @secret,
        timestamp: unix_timestamp_str(-400)
      }

      assert {:error, :timestamp_expired} = SignatureValidator.validate_hmac(params, now)
    end

    test "returns {:error, :timestamp_expired} when timestamp is not a valid integer" do
      signature = sign_body(@raw_body, @secret)
      now = DateTime.utc_now()

      params = %{
        raw_body: @raw_body,
        signature: signature,
        secret: @secret,
        timestamp: "not-a-number"
      }

      assert {:error, :timestamp_expired} = SignatureValidator.validate_hmac(params, now)
    end
  end

  describe "validate_timestamp/2" do
    test "returns :ok when timestamp is within the 5-minute window" do
      now = DateTime.utc_now()
      recent = DateTime.add(now, -60, :second)
      timestamp_str = DateTime.to_unix(recent) |> to_string()

      assert :ok = SignatureValidator.validate_timestamp(timestamp_str, now)
    end

    test "returns {:error, :timestamp_expired} when timestamp is older than 5 minutes" do
      now = DateTime.utc_now()
      old = DateTime.add(now, -400, :second)
      timestamp_str = DateTime.to_unix(old) |> to_string()

      assert {:error, :timestamp_expired} =
               SignatureValidator.validate_timestamp(timestamp_str, now)
    end

    test "returns {:error, :timestamp_expired} when timestamp string is not a unix integer" do
      now = DateTime.utc_now()

      assert {:error, :timestamp_expired} = SignatureValidator.validate_timestamp("abc", now)
    end

    test "returns {:error, :timestamp_expired} when timestamp string is nil" do
      now = DateTime.utc_now()

      assert {:error, :timestamp_expired} = SignatureValidator.validate_timestamp(nil, now)
    end

    test "returns :ok when timestamp is exactly at the boundary" do
      now = DateTime.utc_now()
      boundary = DateTime.add(now, -300, :second)
      timestamp_str = DateTime.to_unix(boundary) |> to_string()

      assert :ok = SignatureValidator.validate_timestamp(timestamp_str, now)
    end

    test "returns {:error, :timestamp_expired} when timestamp is in the future" do
      now = DateTime.utc_now()

      assert {:error, :timestamp_expired} =
               SignatureValidator.validate_timestamp(unix_timestamp_str(+400), now)
    end

    test "returns :ok for a slightly-future timestamp within the window (clock skew)" do
      now = DateTime.utc_now()

      assert :ok = SignatureValidator.validate_timestamp(unix_timestamp_str(+60), now)
    end
  end
end
