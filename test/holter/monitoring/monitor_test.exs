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
end
