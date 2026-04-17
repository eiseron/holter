defmodule Holter.Monitoring.Workers.WorkerUniquenessTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo

  alias Holter.Monitoring.Workers.HTTPCheck
  alias Holter.Monitoring.Workers.SSLCheck

  setup do
    monitor = monitor_fixture()
    %{monitor: monitor}
  end

  describe "HTTPCheck uniqueness" do
    test "prevents duplicate jobs for the same monitor", %{monitor: monitor} do
      args = %{"id" => monitor.id}

      assert {:ok, _job1} = HTTPCheck.new(args) |> Oban.insert()
      assert_enqueued(worker: HTTPCheck, args: args)

      assert {:ok, _job2} = HTTPCheck.new(args) |> Oban.insert()

      jobs = Repo.all(Oban.Job)

      assert length(
               Enum.filter(jobs, fn j ->
                 j.worker == "Holter.Monitoring.Workers.HTTPCheck" and j.args == args
               end)
             ) == 1
    end

    test "allows concurrent jobs for different monitors", %{monitor: monitor} do
      monitor2 = monitor_fixture(%{url: "https://other.com"})

      assert {:ok, _job1} = HTTPCheck.new(%{"id" => monitor.id}) |> Oban.insert()
      assert {:ok, _job2} = HTTPCheck.new(%{"id" => monitor2.id}) |> Oban.insert()

      assert_enqueued(worker: HTTPCheck, args: %{"id" => monitor.id})
      assert_enqueued(worker: HTTPCheck, args: %{"id" => monitor2.id})
    end
  end

  describe "SSLCheck uniqueness" do
    test "prevents duplicate jobs for the same monitor", %{monitor: monitor} do
      args = %{"id" => monitor.id}

      assert {:ok, _job1} = SSLCheck.new(args) |> Oban.insert()
      assert_enqueued(worker: SSLCheck, args: args)

      assert {:ok, _job2} = SSLCheck.new(args) |> Oban.insert()

      jobs = Repo.all(Oban.Job)

      assert length(
               Enum.filter(jobs, fn j ->
                 j.worker == "Holter.Monitoring.Workers.SSLCheck" and j.args == args
               end)
             ) == 1
    end
  end
end
