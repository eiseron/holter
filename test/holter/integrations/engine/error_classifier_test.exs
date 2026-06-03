defmodule Holter.Integrations.Engine.ErrorClassifierTest do
  use ExUnit.Case, async: true

  alias Holter.Integrations.Engine.ErrorClassifier

  describe "classify_error/1" do
    test "classifies HTTP 401 as :token_expired" do
      assert :token_expired = ErrorClassifier.classify_error({:status, 401, %{}})
    end

    test "classifies HTTP 403 as :revoked" do
      assert :revoked = ErrorClassifier.classify_error({:status, 403, %{}})
    end

    test "classifies HTTP 429 as :rate_limited" do
      assert :rate_limited = ErrorClassifier.classify_error({:status, 429, %{}})
    end

    test "classifies HTTP 500 as :provider_down" do
      assert :provider_down = ErrorClassifier.classify_error({:status, 500, %{}})
    end

    test "classifies HTTP 503 as :provider_down" do
      assert :provider_down = ErrorClassifier.classify_error({:status, 503, %{}})
    end

    test "classifies :unauthorized atom as :token_expired" do
      assert :token_expired = ErrorClassifier.classify_error(:unauthorized)
    end

    test "classifies :revoked atom as :revoked" do
      assert :revoked = ErrorClassifier.classify_error(:revoked)
    end

    test "classifies :rate_limited atom as :rate_limited" do
      assert :rate_limited = ErrorClassifier.classify_error(:rate_limited)
    end

    test "classifies unknown errors as :invalid_payload" do
      assert :invalid_payload = ErrorClassifier.classify_error({:unknown, "reason"})
    end
  end

  describe "build_error_update_attrs/2" do
    test "builds reauth_required attrs for :revoked" do
      now = ~U[2026-01-01 12:00:00Z]

      result = ErrorClassifier.build_error_update_attrs(:revoked, %{reason: :revoked, now: now})

      assert %{status: :reauth_required, last_error_at: ^now, last_error_reason: "token_revoked"} =
               result
    end

    test "builds rate_limited attrs for :rate_limited" do
      now = ~U[2026-01-01 12:00:00Z]

      result =
        ErrorClassifier.build_error_update_attrs(:rate_limited, %{reason: :rate_limited, now: now})

      assert %{status: :rate_limited, last_error_at: ^now} = result
    end

    test "builds provider_down attrs for :provider_down" do
      now = ~U[2026-01-01 12:00:00Z]

      result =
        ErrorClassifier.build_error_update_attrs(:provider_down, %{reason: :timeout, now: now})

      assert %{status: :provider_down, last_error_at: ^now} = result
    end

    test "returns empty map for :token_expired" do
      now = ~U[2026-01-01 12:00:00Z]

      assert %{} =
               ErrorClassifier.build_error_update_attrs(:token_expired, %{
                 reason: :expired,
                 now: now
               })
    end

    test "returns empty map for :invalid_payload" do
      now = ~U[2026-01-01 12:00:00Z]

      assert %{} =
               ErrorClassifier.build_error_update_attrs(:invalid_payload, %{
                 reason: :bad,
                 now: now
               })
    end
  end

  describe "determine_retry_strategy/1" do
    test "returns {:error, _} for :token_expired to allow retry" do
      assert {:error, _} = ErrorClassifier.determine_retry_strategy(:token_expired)
    end

    test "returns {:discard, _} for :revoked" do
      assert {:discard, _} = ErrorClassifier.determine_retry_strategy(:revoked)
    end

    test "returns {:snooze, 60} for :rate_limited" do
      assert {:snooze, 60} = ErrorClassifier.determine_retry_strategy(:rate_limited)
    end

    test "returns {:snooze, 300} for :provider_down" do
      assert {:snooze, 300} = ErrorClassifier.determine_retry_strategy(:provider_down)
    end

    test "returns {:discard, _} for :invalid_payload" do
      assert {:discard, _} = ErrorClassifier.determine_retry_strategy(:invalid_payload)
    end

    test "returns {:discard, _} for unknown error class" do
      assert {:discard, _} = ErrorClassifier.determine_retry_strategy(:some_unknown_error)
    end
  end

  describe "classify_error/1 with atom reasons" do
    test "maps :provider_down atom to :provider_down class" do
      assert :provider_down = ErrorClassifier.classify_error(:provider_down)
    end
  end
end
