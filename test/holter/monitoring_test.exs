defmodule Holter.MonitoringTest do
  use Holter.DataCase

  alias Holter.Monitoring
  alias Holter.Monitoring.Workspace

  @valid_attrs %{
    url: "https://example.com",
    method: :get,
    interval_seconds: 60,
    timeout_seconds: 30,
    raw_keyword_positive: "success, login",
    raw_keyword_negative: "hacked, defaced"
  }
  @invalid_attrs %{url: nil, method: nil, interval_seconds: nil}

  describe "Monitor Context Operations" do
    alias Holter.Monitoring.Monitor

    setup do
      workspace = workspace_fixture()
      valid_attrs = Map.put(@valid_attrs, :workspace_id, workspace.id)
      %{workspace: workspace, valid_attrs: valid_attrs}
    end

    test "Given an existing monitor, when listing monitors, then it returns the monitor within a list",
         %{valid_attrs: valid_attrs} do
      {:ok, monitor} = Monitoring.create_monitor(valid_attrs)
      monitor = %{monitor | raw_keyword_positive: nil, raw_keyword_negative: nil}
      assert Monitoring.list_monitors() == [monitor]
    end

    test "Given an existing monitor id, when fetching by id, then it returns the exact monitor struct",
         %{valid_attrs: valid_attrs} do
      {:ok, monitor} = Monitoring.create_monitor(valid_attrs)
      monitor = %{monitor | raw_keyword_positive: nil, raw_keyword_negative: nil}
      assert Monitoring.get_monitor!(monitor.id) == monitor
    end

    test "Given valid attributes, when creating a monitor, then it successfully persists and returns the structured data",
         %{valid_attrs: valid_attrs} do
      assert {:ok,
              %Monitor{
                url: "https://example.com",
                keyword_positive: ["success", "login"],
                keyword_negative: ["hacked", "defaced"]
              }} =
               Monitoring.create_monitor(valid_attrs)
    end

    test "Given missing required fields, when creating a monitor, then it rejects insertion and returns an error changeset",
         %{workspace: workspace} do
      assert {:error, %Ecto.Changeset{valid?: false}} =
               Monitoring.create_monitor(Map.put(@invalid_attrs, :workspace_id, workspace.id))
    end

    test "Given a monitor, when creating a change template, then it returns an empty tracking changeset properly",
         %{valid_attrs: valid_attrs} do
      {:ok, monitor} = Monitoring.create_monitor(valid_attrs)
      assert %Ecto.Changeset{valid?: true} = Monitoring.change_monitor(monitor)
    end

    test "Given a monitor with keywords, when clearing keywords, then it persists empty positive list",
         %{valid_attrs: valid_attrs} do
      {:ok, monitor} = Monitoring.create_monitor(valid_attrs)

      {:ok, updated} =
        Monitoring.update_monitor(monitor, %{
          "raw_keyword_positive" => "",
          "raw_keyword_negative" => ""
        })

      assert updated.keyword_positive == []
    end

    test "Given a monitor with keywords, when clearing keywords, then it persists empty negative list",
         %{valid_attrs: valid_attrs} do
      {:ok, monitor} = Monitoring.create_monitor(valid_attrs)

      {:ok, updated} =
        Monitoring.update_monitor(monitor, %{
          "raw_keyword_positive" => "",
          "raw_keyword_negative" => ""
        })

      assert updated.keyword_negative == []
    end

    test "Given a monitor with custom headers, when clearing headers, then it persists an empty map",
         %{valid_attrs: valid_attrs} do
      {:ok, monitor} =
        Monitoring.create_monitor(Map.put(valid_attrs, :raw_headers, "{\"X-Test\": \"Value\"}"))

      {:ok, updated} = Monitoring.update_monitor(monitor, %{"raw_headers" => ""})
      assert updated.headers == %{}
    end
  end

  describe "Workspace Context Operations" do
    test "create_workspace/1 with valid data creates a workspace" do
      assert {:ok, %Workspace{name: "Eiseron Corp", slug: "eiseron-corp"}} =
               Monitoring.create_workspace(%{
                 name: "Eiseron Corp",
                 retention_days: 3,
                 max_monitors: 5,
                 min_interval_seconds: 60
               })
    end

    test "create_workspace/1 with unique constraint on slug" do
      {:ok, _workspace} =
        Monitoring.create_workspace(%{
          name: "Eiseron Corp",
          slug: "eiseron",
          retention_days: 3,
          max_monitors: 5,
          min_interval_seconds: 60
        })

      {:error, changeset} =
        Monitoring.create_workspace(%{
          name: "Other Corp",
          slug: "eiseron",
          retention_days: 3,
          max_monitors: 5,
          min_interval_seconds: 60
        })

      assert "has already been taken" in errors_on(changeset).slug
    end

    test "workspace slug is immutable after creation" do
      {:ok, workspace} =
        Monitoring.create_workspace(%{
          name: "Initial Name",
          retention_days: 3,
          max_monitors: 5,
          min_interval_seconds: 60
        })

      {:error, changeset} = Monitoring.update_workspace(workspace, %{slug: "new-slug"})

      assert "cannot be changed after creation" in errors_on(changeset).slug
    end
  end

  describe "find_nearest_technical_log/2" do
    setup do
      monitor = monitor_fixture()
      %{monitor: monitor}
    end

    test "returns nil when no other logs exist", %{monitor: monitor} do
      {:ok, log} = Monitoring.create_monitor_log(%{monitor_id: monitor.id, status: :up, checked_at: DateTime.utc_now()})
      assert Monitoring.find_nearest_technical_log(monitor.id, log) == nil
    end

    test "returns nil when all other logs have no payload", %{monitor: monitor} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Monitoring.create_monitor_log(%{monitor_id: monitor.id, status: :up, checked_at: DateTime.add(now, -60, :second)})
      {:ok, log} = Monitoring.create_monitor_log(%{monitor_id: monitor.id, status: :up, checked_at: now})

      assert Monitoring.find_nearest_technical_log(monitor.id, log) == nil
    end

    test "returns most recent log with non-empty response_headers", %{monitor: monitor} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, with_headers} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :up,
          response_headers: %{"server" => "nginx"},
          checked_at: DateTime.add(now, -60, :second)
        })

      {:ok, log} = Monitoring.create_monitor_log(%{monitor_id: monitor.id, status: :up, checked_at: now})

      assert Monitoring.find_nearest_technical_log(monitor.id, log).id == with_headers.id
    end

    test "returns most recent log with non-empty response_snippet", %{monitor: monitor} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, with_snippet} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :up,
          response_snippet: "some content",
          checked_at: DateTime.add(now, -60, :second)
        })

      {:ok, log} = Monitoring.create_monitor_log(%{monitor_id: monitor.id, status: :up, checked_at: now})

      assert Monitoring.find_nearest_technical_log(monitor.id, log).id == with_snippet.id
    end

    test "does not return the log itself even if it has a payload", %{monitor: monitor} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, log} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :up,
          response_headers: %{"server" => "nginx"},
          checked_at: now
        })

      assert Monitoring.find_nearest_technical_log(monitor.id, log) == nil
    end

    test "does not return logs checked after the target log", %{monitor: monitor} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, log} = Monitoring.create_monitor_log(%{monitor_id: monitor.id, status: :up, checked_at: now})

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :up,
        response_headers: %{"server" => "nginx"},
        checked_at: DateTime.add(now, 60, :second)
      })

      assert Monitoring.find_nearest_technical_log(monitor.id, log) == nil
    end

    test "returns the closest preceding log when multiple candidates exist", %{monitor: monitor} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Monitoring.create_monitor_log(%{
        monitor_id: monitor.id,
        status: :up,
        response_headers: %{"server" => "older"},
        checked_at: DateTime.add(now, -120, :second)
      })

      {:ok, closer} =
        Monitoring.create_monitor_log(%{
          monitor_id: monitor.id,
          status: :up,
          response_headers: %{"server" => "nginx"},
          checked_at: DateTime.add(now, -60, :second)
        })

      {:ok, log} = Monitoring.create_monitor_log(%{monitor_id: monitor.id, status: :up, checked_at: now})

      assert Monitoring.find_nearest_technical_log(monitor.id, log).id == closer.id
    end
  end
end
