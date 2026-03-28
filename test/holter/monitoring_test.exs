defmodule Holter.MonitoringTest do
  use Holter.DataCase

  alias Holter.Monitoring

  describe "Monitor Context Operations" do
    alias Holter.Monitoring.Monitor

    @valid_attrs %{
      url: "https://example.com",
      method: :GET,
      interval_seconds: 60,
      timeout_seconds: 30,
      ssl_ignore: false,
      raw_keyword_positive: "success, login",
      raw_keyword_negative: "hacked ; defaced"
    }

    @invalid_attrs %{
      url: nil,
      method: nil,
      interval_seconds: nil,
      timeout_seconds: nil
    }

    test "Given an existing monitor, when listing monitors, then it returns the monitor within a list" do
      {:ok, monitor} = Monitoring.create_monitor(@valid_attrs)
      monitor = %{monitor | raw_keyword_positive: nil, raw_keyword_negative: nil}
      assert Monitoring.list_monitors() == [monitor]
    end

    test "Given an existing monitor id, when fetching by id, then it returns the exact monitor struct" do
      {:ok, monitor} = Monitoring.create_monitor(@valid_attrs)
      monitor = %{monitor | raw_keyword_positive: nil, raw_keyword_negative: nil}
      assert Monitoring.get_monitor!(monitor.id) == monitor
    end

    test "Given valid attributes, when creating a monitor, then it successfully persists and returns the structured data" do
      assert {:ok, %Monitor{url: "https://example.com", keyword_positive: ["success", "login"], keyword_negative: ["hacked", "defaced"]}} =
               Monitoring.create_monitor(@valid_attrs)
    end

    test "Given missing required fields, when creating a monitor, then it rejects insertion and returns an error changeset" do
      assert {:error, %Ecto.Changeset{valid?: false}} = Monitoring.create_monitor(@invalid_attrs)
    end

    test "Given a monitor, when creating a change template, then it returns an empty tracking changeset properly" do
      {:ok, monitor} = Monitoring.create_monitor(@valid_attrs)
      assert %Ecto.Changeset{valid?: true} = Monitoring.change_monitor(monitor)
    end
  end
end
