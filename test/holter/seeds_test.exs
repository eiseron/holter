defmodule Holter.SeedsTest do
  @moduledoc """
  Behavior tests for the per-domain seed modules under priv/repo/seeds/.

  Seeds run on every preview deploy; reviewers landing on an empty dashboard
  is a UX regression that's hard to spot in code review. These tests assert
  the seed contract — counts, health-state distribution, open vs resolved
  incidents — so a regression that breaks the populated dashboard fails CI
  before it reaches a preview environment.
  """

  use Holter.DataCase, async: true

  import Ecto.Query, only: [from: 2]
  import ExUnit.CaptureIO, only: [with_io: 1]

  @compile {:no_warn_undefined,
            [
              Holter.Seeds.Time,
              Holter.Seeds.Monitoring.Workspaces,
              Holter.Seeds.Monitoring.Monitors,
              Holter.Seeds.Monitoring.Incidents,
              Holter.Seeds.Monitoring.DailyMetrics,
              Holter.Seeds.Delivery.WebhookChannels,
              Holter.Seeds.Delivery.EmailChannels
            ]}

  alias Holter.Delivery.{
    EmailChannel,
    EmailChannelRecipient,
    MonitorEmailChannel,
    MonitorWebhookChannel,
    WebhookChannel
  }

  alias Holter.Monitoring.{DailyMetric, Incident, Monitor, Workspace}
  alias Holter.Seeds.Delivery.{EmailChannels, WebhookChannels}
  alias Holter.Seeds.Monitoring.{DailyMetrics, Incidents, Monitors, Workspaces}
  alias Holter.Seeds.Time

  @seeds_dir Path.expand("../../priv/repo/seeds", __DIR__)

  setup_all do
    Code.require_file(Path.join(@seeds_dir, "time.exs"))
    Code.require_file(Path.join(@seeds_dir, "monitoring/workspaces.exs"))
    Code.require_file(Path.join(@seeds_dir, "monitoring/monitors.exs"))
    Code.require_file(Path.join(@seeds_dir, "monitoring/incidents.exs"))
    Code.require_file(Path.join(@seeds_dir, "monitoring/daily_metrics.exs"))
    Code.require_file(Path.join(@seeds_dir, "delivery/webhook_channels.exs"))
    Code.require_file(Path.join(@seeds_dir, "delivery/email_channels.exs"))
    :ok
  end

  describe "Holter.Seeds.Time" do
    test "Given a positive offset, when calling ago/1, then it returns a past DateTime" do
      ts = Time.ago(60)
      assert DateTime.compare(ts, DateTime.utc_now()) == :lt
    end

    test "Given a positive offset, when calling ahead/1, then it returns a future DateTime" do
      ts = Time.ahead(60)
      assert DateTime.compare(ts, DateTime.utc_now()) == :gt
    end

    test "Given Time.minute/0, when reading it, then it returns 60 seconds" do
      assert Time.minute() == 60
    end

    test "Given Time.hour/0, when reading it, then it returns 3600 seconds" do
      assert Time.hour() == 3_600
    end

    test "Given Time.day/0, when reading it, then it returns 86400 seconds" do
      assert Time.day() == 86_400
    end
  end

  describe "Holter.Seeds.Monitoring.Workspaces.create_default/0" do
    test "Given an empty database, when seeding workspaces, then it inserts exactly one 'dev' workspace" do
      {_workspace, _io} = with_io(fn -> Workspaces.create_default() end)

      assert [%Workspace{slug: "dev", name: "Development"}] = Repo.all(Workspace)
    end
  end

  describe "Holter.Seeds.Monitoring.Monitors.create_for/1" do
    setup do
      {workspace, _io} = with_io(fn -> Workspaces.create_default() end)
      %{workspace: workspace}
    end

    test "Given a workspace, when seeding monitors, then it inserts seven monitors covering the documented health states",
         %{workspace: workspace} do
      {_monitors, _io} = with_io(fn -> Monitors.create_for(workspace) end)

      monitors = Repo.all(Monitor)
      assert length(monitors) == 7

      health_counts = Enum.frequencies_by(monitors, & &1.health_status)
      assert health_counts[:up] == 2
      assert health_counts[:down] == 1
      assert health_counts[:degraded] == 3
      assert health_counts[:unknown] == 1
    end

    test "Given the seeded monitors, when checking logical state, then exactly one is paused",
         %{workspace: workspace} do
      {_monitors, _io} = with_io(fn -> Monitors.create_for(workspace) end)

      paused = Repo.all(Monitor) |> Enum.filter(&(&1.logical_state == :paused))
      assert length(paused) == 1
    end

    test "Given the seeded monitors, when looking at expiry hints, then SSL and domain warnings are populated",
         %{workspace: workspace} do
      {_monitors, _io} = with_io(fn -> Monitors.create_for(workspace) end)

      monitors = Repo.all(Monitor)
      assert Enum.any?(monitors, &(not is_nil(&1.ssl_expires_at)))
      assert Enum.any?(monitors, &(not is_nil(&1.domain_expires_at)))
    end
  end

  describe "Holter.Seeds.Monitoring.Incidents.create_for/1" do
    setup do
      {workspace, _io} = with_io(fn -> Workspaces.create_default() end)
      {monitors, _io} = with_io(fn -> Monitors.create_for(workspace) end)
      %{monitors: monitors}
    end

    test "Given the seeded monitors, when seeding incidents, then it inserts four incidents with two open and two resolved",
         %{monitors: monitors} do
      with_io(fn -> Incidents.create_for(monitors) end)

      incidents = Repo.all(Incident)
      assert length(incidents) == 4
      assert Enum.count(incidents, &is_nil(&1.resolved_at)) == 2
      assert Enum.count(incidents, &(not is_nil(&1.resolved_at))) == 2
    end

    test "Given the seeded incidents, when grouping by type, then both downtime and ssl_expiry are represented",
         %{monitors: monitors} do
      with_io(fn -> Incidents.create_for(monitors) end)

      types = Repo.all(Incident) |> Enum.map(& &1.type) |> Enum.uniq() |> Enum.sort()
      assert :downtime in types
      assert :ssl_expiry in types
    end
  end

  describe "Holter.Seeds.Monitoring.DailyMetrics.create_for/1" do
    setup do
      {workspace, _io} = with_io(fn -> Workspaces.create_default() end)
      {monitors, _io} = with_io(fn -> Monitors.create_for(workspace) end)
      %{monitors: monitors}
    end

    test "Given the seeded monitors, when seeding daily metrics, then it inserts seventeen rows across the seven-day window",
         %{monitors: monitors} do
      with_io(fn -> DailyMetrics.create_for(monitors) end)

      metrics = Repo.all(DailyMetric)
      assert length(metrics) == 17
      dates = metrics |> Enum.map(& &1.date) |> Enum.uniq()
      today = Date.utc_today()
      assert today in dates
      assert Date.add(today, -6) in dates
    end
  end

  describe "Holter.Seeds.Delivery.WebhookChannels.create_for/2" do
    setup do
      {workspace, _io} = with_io(fn -> Workspaces.create_default() end)
      {monitors, _io} = with_io(fn -> Monitors.create_for(workspace) end)
      %{workspace: workspace, monitors: monitors}
    end

    test "Given a workspace with monitors, when seeding webhook channels, then it inserts two channels named after typical Ops integrations",
         %{workspace: workspace, monitors: monitors} do
      with_io(fn -> WebhookChannels.create_for(workspace, monitors) end)

      names = Repo.all(WebhookChannel) |> Enum.map(& &1.name) |> Enum.sort()
      assert names == ["Ops Slack", "PagerDuty critical"]
    end

    test "Given the seeded webhook channels, when inspecting URLs, then both target public HTTPS endpoints",
         %{workspace: workspace, monitors: monitors} do
      with_io(fn -> WebhookChannels.create_for(workspace, monitors) end)

      assert Enum.all?(Repo.all(WebhookChannel), &String.starts_with?(&1.url, "https://"))
    end

    test "Given the seeded webhook channels, when inspecting signing tokens, then each one has a non-empty token",
         %{workspace: workspace, monitors: monitors} do
      with_io(fn -> WebhookChannels.create_for(workspace, monitors) end)

      assert Enum.all?(
               Repo.all(WebhookChannel),
               &(is_binary(&1.signing_token) and &1.signing_token != "")
             )
    end

    test "Given the seeded webhook channels, when counting monitor links, then Ops Slack covers six monitors and PagerDuty two",
         %{workspace: workspace, monitors: monitors} do
      with_io(fn -> WebhookChannels.create_for(workspace, monitors) end)

      counts =
        Repo.all(WebhookChannel)
        |> Map.new(fn c ->
          {c.name,
           Repo.aggregate(
             from(l in MonitorWebhookChannel, where: l.webhook_channel_id == ^c.id),
             :count
           )}
        end)

      assert counts == %{"Ops Slack" => 6, "PagerDuty critical" => 2}
    end
  end

  describe "Holter.Seeds.Delivery.EmailChannels.create_for/2" do
    setup do
      {workspace, _io} = with_io(fn -> Workspaces.create_default() end)
      {monitors, _io} = with_io(fn -> Monitors.create_for(workspace) end)
      %{workspace: workspace, monitors: monitors}
    end

    test "Given a workspace with monitors, when seeding email channels, then it inserts three channels covering the verified/pending UI states",
         %{workspace: workspace, monitors: monitors} do
      with_io(fn -> EmailChannels.create_for(workspace, monitors) end)

      names = Repo.all(EmailChannel) |> Enum.map(& &1.name) |> Enum.sort()
      assert names == ["Engineering team", "On-call rotation", "Stakeholders"]
    end

    test "Given the seeded email channels, when partitioning by verification, then exactly one is awaiting verification",
         %{workspace: workspace, monitors: monitors} do
      with_io(fn -> EmailChannels.create_for(workspace, monitors) end)

      pending = Repo.all(EmailChannel) |> Enum.count(&is_nil(&1.verified_at))
      assert pending == 1
    end

    test "Given the seeded email channels, when counting recipients, then four rows exist",
         %{workspace: workspace, monitors: monitors} do
      with_io(fn -> EmailChannels.create_for(workspace, monitors) end)

      assert Repo.aggregate(EmailChannelRecipient, :count) == 4
    end

    test "Given the seeded email channels, when partitioning recipients by verification, then exactly one is still awaiting verification",
         %{workspace: workspace, monitors: monitors} do
      with_io(fn -> EmailChannels.create_for(workspace, monitors) end)

      pending = Repo.all(EmailChannelRecipient) |> Enum.count(&is_nil(&1.verified_at))
      assert pending == 1
    end

    test "Given the seeded email channels, when counting monitor links, then nine join rows exist (6 Engineering + 3 On-call)",
         %{workspace: workspace, monitors: monitors} do
      with_io(fn -> EmailChannels.create_for(workspace, monitors) end)

      assert Repo.aggregate(MonitorEmailChannel, :count) == 9
    end
  end
end
