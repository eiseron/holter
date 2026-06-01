defmodule Holter.Integrations.RateLimiterTest do
  use ExUnit.Case, async: false

  alias Holter.Integrations.RateLimiter

  setup do
    Application.put_env(:holter, :integration_rate_limits, %{
      test_provider: {5_000, 3},
      other_provider: {5_000, 3}
    })

    on_exit(fn ->
      Application.put_env(:holter, :integration_rate_limits, %{
        google_ads: {:timer.hours(24), 1_000_000},
        meta_ads: {:timer.hours(1), 1_000_000},
        slack: {:timer.minutes(1), 1_000_000}
      })
    end)

    :ok
  end

  describe "check_rate/2" do
    test "returns :ok when under the limit" do
      id = "integration-#{System.unique_integer([:positive])}"

      assert :ok = RateLimiter.check_rate(id, :test_provider)
    end

    test "returns {:error, :rate_limited} after exceeding the limit" do
      id = "integration-#{System.unique_integer([:positive])}"

      Enum.each(1..3, fn _ -> RateLimiter.check_rate(id, :test_provider) end)

      assert {:error, :rate_limited} = RateLimiter.check_rate(id, :test_provider)
    end

    test "buckets are isolated per integration id" do
      id_a = "integration-a-#{System.unique_integer([:positive])}"
      id_b = "integration-b-#{System.unique_integer([:positive])}"

      Enum.each(1..3, fn _ -> RateLimiter.check_rate(id_a, :test_provider) end)

      assert :ok = RateLimiter.check_rate(id_b, :test_provider)
    end

    test "buckets are isolated per provider for the same integration id" do
      id = "integration-#{System.unique_integer([:positive])}"

      Enum.each(1..4, fn _ -> RateLimiter.check_rate(id, :test_provider) end)

      assert :ok = RateLimiter.check_rate(id, :other_provider)
    end
  end
end
