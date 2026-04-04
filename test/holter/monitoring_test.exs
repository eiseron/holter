defmodule Holter.MonitoringTest do
  use Holter.DataCase

  alias Holter.Monitoring

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
      org = organization_fixture()
      valid_attrs = Map.put(@valid_attrs, :organization_id, org.id)
      %{org: org, valid_attrs: valid_attrs}
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

    test "Given missing required fields, when creating a monitor, then it rejects insertion and returns an error changeset" do
      assert {:error, %Ecto.Changeset{valid?: false}} = Monitoring.create_monitor(@invalid_attrs)
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

  describe "Organization Context Operations" do
    test "create_organization/1 with valid data creates an organization" do
      assert {:ok, %{name: "Eiseron Corp", slug: "eiseron-corp"}} =
               Monitoring.create_organization(%{name: "Eiseron Corp"})
    end

    test "create_organization/1 with unique constraint on slug" do
      {:ok, _org} = Monitoring.create_organization(%{name: "Eiseron Corp", slug: "eiseron"})

      {:error, changeset} =
        Monitoring.create_organization(%{name: "Other Corp", slug: "eiseron"})

      assert "has already been taken" in errors_on(changeset).slug
    end

    test "organization slug is immutable after creation" do
      {:ok, org} = Monitoring.create_organization(%{name: "Initial Name"})

      {:error, changeset} = Monitoring.update_organization(org, %{slug: "new-slug"})

      assert "cannot be changed after creation" in errors_on(changeset).slug
    end
  end
end
