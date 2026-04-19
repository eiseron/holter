defmodule Holter.Observability.ObanHandlerTest do
  use ExUnit.Case, async: true

  alias Holter.Observability.ObanHandler

  @fake_job %{id: 42, worker: "MyWorker", queue: "default", args: %{}}

  describe "attach/0" do
    test "registers handler successfully (idempotent)" do
      :telemetry.detach("holter-oban-logger")
      assert ObanHandler.attach() == :ok
    end
  end

  describe "handle_event/4 with :start" do
    test "sets job_id in Logger metadata" do
      ObanHandler.handle_event([:oban, :job, :start], %{}, %{job: @fake_job}, nil)
      assert Logger.metadata()[:job_id] == 42
    end

    test "sets job_queue in Logger metadata" do
      ObanHandler.handle_event([:oban, :job, :start], %{}, %{job: @fake_job}, nil)
      assert Logger.metadata()[:job_queue] == "default"
    end

    test "sets context to :oban_job in Logger metadata" do
      ObanHandler.handle_event([:oban, :job, :start], %{}, %{job: @fake_job}, nil)
      assert Logger.metadata()[:context] == :oban_job
    end

    test "sets job_worker as inspect string in Logger metadata" do
      ObanHandler.handle_event([:oban, :job, :start], %{}, %{job: @fake_job}, nil)
      assert Logger.metadata()[:job_worker] == inspect(@fake_job.worker)
    end
  end

  describe "handle_event/4 with :stop" do
    test "returns :ok" do
      assert ObanHandler.handle_event([:oban, :job, :stop], %{}, %{job: @fake_job}, nil) == :ok
    end
  end

  describe "handle_event/4 with :exception" do
    test "returns :ok" do
      assert ObanHandler.handle_event([:oban, :job, :exception], %{}, %{job: @fake_job}, nil) ==
               :ok
    end
  end
end
