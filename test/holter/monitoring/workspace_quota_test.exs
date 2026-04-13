defmodule Holter.Monitoring.WorkspaceQuotaTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring
  alias Holter.Monitoring.Monitor

  describe "create_monitor/1 — max_monitors quota" do
    test "rejects when workspace is at capacity" do
      workspace = workspace_fixture(%{max_monitors: 1})
      monitor_fixture(%{workspace_id: workspace.id})

      assert {:error, :quota_reached} =
               Monitoring.create_monitor(%{
                 url: "https://example.com",
                 method: "get",
                 interval_seconds: 60,
                 timeout_seconds: 30,
                 workspace_id: workspace.id
               })
    end

    test "accepts when workspace is below capacity" do
      workspace = workspace_fixture(%{max_monitors: 2})
      monitor_fixture(%{workspace_id: workspace.id})

      assert {:ok, _monitor} =
               Monitoring.create_monitor(%{
                 url: "https://example.com",
                 method: "get",
                 interval_seconds: 60,
                 timeout_seconds: 30,
                 workspace_id: workspace.id
               })
    end

    test "does not count archived monitors against the quota" do
      workspace = workspace_fixture(%{max_monitors: 1})
      monitor = monitor_fixture(%{workspace_id: workspace.id})
      {:ok, _} = Monitoring.update_monitor(monitor, %{logical_state: :archived})

      assert {:ok, _monitor} =
               Monitoring.create_monitor(%{
                 url: "https://example.com",
                 method: "get",
                 interval_seconds: 60,
                 timeout_seconds: 30,
                 workspace_id: workspace.id
               })
    end
  end

  describe "create_monitor/1 — min_interval_seconds" do
    test "rejects interval below workspace minimum" do
      workspace = workspace_fixture(%{min_interval_seconds: 300})

      {:error, changeset} =
        Monitoring.create_monitor(%{
          url: "https://example.com",
          method: "get",
          interval_seconds: 60,
          timeout_seconds: 30,
          workspace_id: workspace.id
        })

      assert changeset.errors[:interval_seconds]
    end

    test "accepts interval equal to workspace minimum" do
      workspace = workspace_fixture(%{min_interval_seconds: 300})

      assert {:ok, _monitor} =
               Monitoring.create_monitor(%{
                 url: "https://example.com",
                 method: "get",
                 interval_seconds: 300,
                 timeout_seconds: 30,
                 workspace_id: workspace.id
               })
    end
  end

  describe "update_monitor/2 — min_interval_seconds" do
    test "rejects interval below workspace minimum" do
      workspace = workspace_fixture(%{min_interval_seconds: 300})
      monitor = monitor_fixture(%{workspace_id: workspace.id, interval_seconds: 300})

      {:error, changeset} = Monitoring.update_monitor(monitor, %{interval_seconds: 60})

      assert changeset.errors[:interval_seconds]
    end

    test "accepts interval equal to workspace minimum" do
      workspace = workspace_fixture(%{min_interval_seconds: 300})
      monitor = monitor_fixture(%{workspace_id: workspace.id, interval_seconds: 300})

      assert {:ok, %{interval_seconds: 300}} =
               Monitoring.update_monitor(monitor, %{interval_seconds: 300})
    end
  end

  describe "Monitor.changeset — timeout vs interval" do
    test "rejects timeout >= interval_seconds" do
      changeset =
        Monitor.changeset(%Monitor{}, %{
          url: "https://example.com",
          method: :get,
          interval_seconds: 60,
          timeout_seconds: 60,
          workspace_id: Ecto.UUID.generate()
        })

      assert changeset.errors[:timeout_seconds]
    end

    test "accepts timeout < interval_seconds" do
      changeset =
        Monitor.changeset(%Monitor{}, %{
          url: "https://example.com",
          method: :get,
          interval_seconds: 60,
          timeout_seconds: 30,
          workspace_id: Ecto.UUID.generate()
        })

      refute changeset.errors[:timeout_seconds]
    end
  end

  describe "Monitor.changeset — body and HTTP method" do
    test "rejects body on GET request" do
      changeset =
        Monitor.changeset(%Monitor{}, %{
          url: "https://example.com",
          method: :get,
          interval_seconds: 60,
          timeout_seconds: 30,
          body: "{\"key\": \"value\"}",
          workspace_id: Ecto.UUID.generate()
        })

      assert changeset.errors[:body]
    end

    test "rejects body on HEAD request" do
      changeset =
        Monitor.changeset(%Monitor{}, %{
          url: "https://example.com",
          method: :head,
          interval_seconds: 60,
          timeout_seconds: 30,
          body: "{\"key\": \"value\"}",
          workspace_id: Ecto.UUID.generate()
        })

      assert changeset.errors[:body]
    end

    test "accepts body on POST request" do
      changeset =
        Monitor.changeset(%Monitor{}, %{
          url: "https://example.com",
          method: :post,
          interval_seconds: 60,
          timeout_seconds: 30,
          body: "{\"key\": \"value\"}",
          workspace_id: Ecto.UUID.generate()
        })

      refute changeset.errors[:body]
    end

    test "rejects invalid JSON in body on POST request" do
      changeset =
        Monitor.changeset(%Monitor{}, %{
          url: "https://example.com",
          method: :post,
          interval_seconds: 60,
          timeout_seconds: 30,
          body: "not valid json",
          workspace_id: Ecto.UUID.generate()
        })

      assert changeset.errors[:body]
    end

    test "accepts valid JSON in body on POST request" do
      changeset =
        Monitor.changeset(%Monitor{}, %{
          url: "https://example.com",
          method: :post,
          interval_seconds: 60,
          timeout_seconds: 30,
          body: "{\"action\": \"ping\"}",
          workspace_id: Ecto.UUID.generate()
        })

      refute changeset.errors[:body]
    end

    test "accepts empty body on POST request" do
      changeset =
        Monitor.changeset(%Monitor{}, %{
          url: "https://example.com",
          method: :post,
          interval_seconds: 60,
          timeout_seconds: 30,
          body: "",
          workspace_id: Ecto.UUID.generate()
        })

      refute changeset.errors[:body]
    end
  end

  describe "Monitor.changeset — ssl_ignore" do
    test "rejects ssl_ignore: true on HTTP URL" do
      changeset =
        Monitor.changeset(%Monitor{}, %{
          url: "http://example.com",
          method: :get,
          interval_seconds: 60,
          timeout_seconds: 30,
          ssl_ignore: true,
          workspace_id: Ecto.UUID.generate()
        })

      assert changeset.errors[:ssl_ignore]
    end

    test "accepts ssl_ignore: true on HTTPS URL" do
      changeset =
        Monitor.changeset(%Monitor{}, %{
          url: "https://example.com",
          method: :get,
          interval_seconds: 60,
          timeout_seconds: 30,
          ssl_ignore: true,
          workspace_id: Ecto.UUID.generate()
        })

      refute changeset.errors[:ssl_ignore]
    end
  end

  describe "Monitor.changeset — keyword count limit" do
    test "rejects keyword list exceeding 20 items" do
      keywords = Enum.map_join(1..21, ", ", &"keyword#{&1}")

      changeset =
        Monitor.changeset(%Monitor{}, %{
          url: "https://example.com",
          method: :get,
          interval_seconds: 60,
          timeout_seconds: 30,
          raw_keyword_positive: keywords,
          workspace_id: Ecto.UUID.generate()
        })

      assert changeset.errors[:keyword_positive]
    end

    test "accepts keyword list at exactly 20 items" do
      keywords = Enum.map_join(1..20, ", ", &"keyword#{&1}")

      changeset =
        Monitor.changeset(%Monitor{}, %{
          url: "https://example.com",
          method: :get,
          interval_seconds: 60,
          timeout_seconds: 30,
          raw_keyword_positive: keywords,
          workspace_id: Ecto.UUID.generate()
        })

      refute changeset.errors[:keyword_positive]
    end
  end
end
