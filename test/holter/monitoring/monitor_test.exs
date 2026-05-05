defmodule Holter.Monitoring.MonitorTest do
  use ExUnit.Case, async: true

  alias Holter.Monitoring.Monitor

  defp base_attrs(overrides) do
    Map.merge(
      %{
        url: "https://example.com",
        method: :get,
        timeout_seconds: 30,
        workspace_id: Ecto.UUID.generate()
      },
      overrides
    )
  end

  describe "interval_max_seconds/0" do
    test "advertises 24 hours so the form and API agree" do
      assert Monitor.interval_max_seconds() == 86_400
    end
  end

  describe "changeset — interval_seconds upper bound" do
    test "accepts a 24-hour interval" do
      changeset = Monitor.changeset(%Monitor{}, base_attrs(%{interval_seconds: 86_400}))

      refute changeset.errors[:interval_seconds]
    end

    test "rejects an interval above 24 hours" do
      changeset = Monitor.changeset(%Monitor{}, base_attrs(%{interval_seconds: 86_401}))

      assert changeset.errors[:interval_seconds]
    end
  end

  describe "changeset — timeout vs interval" do
    test "accepts timeout strictly less than interval" do
      changeset =
        Monitor.changeset(
          %Monitor{},
          base_attrs(%{interval_seconds: 60, timeout_seconds: 30})
        )

      refute changeset.errors[:timeout_seconds]
    end

    test "rejects timeout equal to interval" do
      changeset =
        Monitor.changeset(
          %Monitor{},
          base_attrs(%{interval_seconds: 30, timeout_seconds: 30})
        )

      {msg, _} = changeset.errors[:timeout_seconds]
      assert msg =~ "must be less than the check interval"
    end

    test "rejects timeout greater than interval" do
      changeset =
        Monitor.changeset(
          %Monitor{},
          base_attrs(%{interval_seconds: 20, timeout_seconds: 25})
        )

      {msg, _} = changeset.errors[:timeout_seconds]
      assert msg =~ "must be less than the check interval"
    end

    test "echoes the configured interval in the error message" do
      changeset =
        Monitor.changeset(
          %Monitor{},
          base_attrs(%{interval_seconds: 25, timeout_seconds: 25})
        )

      {msg, _} = changeset.errors[:timeout_seconds]
      assert msg =~ "25s"
    end
  end

  describe "changeset — body allowed for method" do
    test "rejects a non-empty body for GET" do
      changeset =
        Monitor.changeset(
          %Monitor{},
          base_attrs(%{method: :get, body: "{}", interval_seconds: 60})
        )

      {msg, _} = changeset.errors[:body]
      assert msg =~ "must be empty for"
    end

    test "rejects a non-empty body for HEAD" do
      changeset =
        Monitor.changeset(
          %Monitor{},
          base_attrs(%{method: :head, body: "{}", interval_seconds: 60})
        )

      assert changeset.errors[:body]
    end

    test "accepts an empty body for GET" do
      changeset =
        Monitor.changeset(
          %Monitor{},
          base_attrs(%{method: :get, body: "", interval_seconds: 60})
        )

      refute changeset.errors[:body]
    end

    test "accepts a body for POST" do
      changeset =
        Monitor.changeset(
          %Monitor{},
          base_attrs(%{method: :post, body: ~s({"k":1}), interval_seconds: 60})
        )

      refute changeset.errors[:body]
    end
  end

  describe "changeset — body must be valid JSON for body methods" do
    test "rejects malformed JSON body for POST" do
      changeset =
        Monitor.changeset(
          %Monitor{},
          base_attrs(%{method: :post, body: "{not-json}", interval_seconds: 60})
        )

      {msg, _} = changeset.errors[:body]
      assert msg =~ "must be a valid JSON string"
    end

    test "accepts valid JSON body for PUT" do
      changeset =
        Monitor.changeset(
          %Monitor{},
          base_attrs(%{method: :put, body: ~s({"key":"v"}), interval_seconds: 60})
        )

      refute changeset.errors[:body]
    end

    test "accepts valid JSON body for PATCH" do
      changeset =
        Monitor.changeset(
          %Monitor{},
          base_attrs(%{method: :patch, body: ~s([1,2,3]), interval_seconds: 60})
        )

      refute changeset.errors[:body]
    end
  end

  describe "changeset — ssl_ignore requires HTTPS" do
    test "rejects ssl_ignore on an HTTP URL" do
      changeset =
        Monitor.changeset(
          %Monitor{},
          base_attrs(%{
            url: "http://example.com",
            ssl_ignore: true,
            interval_seconds: 60
          })
        )

      {msg, _} = changeset.errors[:ssl_ignore]
      assert msg =~ "is only applicable to HTTPS URLs"
    end

    test "accepts ssl_ignore on an HTTPS URL" do
      changeset =
        Monitor.changeset(
          %Monitor{},
          base_attrs(%{
            url: "https://example.com",
            ssl_ignore: true,
            interval_seconds: 60
          })
        )

      refute changeset.errors[:ssl_ignore]
    end
  end
end
