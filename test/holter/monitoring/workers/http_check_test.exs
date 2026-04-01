defmodule Holter.Monitoring.Workers.HTTPCheckTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo
  import Mox

  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.HTTPCheck
  alias Holter.Monitoring.MonitorClientMock

  @monitor_attrs %{
    url: "https://test.local",
    method: "GET",
    interval_seconds: 60,
    logical_state: :active,
    raw_keyword_positive: "success",
    raw_keyword_negative: "error",
    health_status: :up
  }

  setup do
    {:ok, monitor} = Monitoring.create_monitor(@monitor_attrs)
    %{monitor: monitor}
  end

  describe "perform/1 with 200 OK and matching keywords" do
    setup %{monitor: monitor} do
      stub_response(%{message: "success"}, 200)
      :ok = perform_job(HTTPCheck, job_args(monitor))
    end

    test "sets health_status to :up", %{monitor: monitor} do
      assert current_status(monitor) == :up
    end
  end

  describe "perform/1 with missing positive keyword" do
    setup %{monitor: monitor} do
      stub_response(%{message: "failure"}, 200)
      :ok = perform_job(HTTPCheck, job_args(monitor))
    end

    test "sets health_status to :down", %{monitor: monitor} do
      assert current_status(monitor) == :down
    end
  end

  describe "perform/1 with negative keyword present" do
    setup %{monitor: monitor} do
      stub_response(%{message: "success but has error"}, 200)
      :ok = perform_job(HTTPCheck, job_args(monitor))
    end

    test "sets health_status to :down", %{monitor: monitor} do
      assert current_status(monitor) == :down
    end
  end

  describe "perform/1 logging on successful check" do
    setup %{monitor: monitor} do
      stub_response(%{message: "success"}, 200)
      :ok = perform_job(HTTPCheck, job_args(monitor))
    end

    test "records :success status in log", %{monitor: monitor} do
      assert [%{status: :success}] = Monitoring.list_monitor_logs(monitor.id)
    end

    test "records HTTP status code in log", %{monitor: monitor} do
      assert [%{status_code: 200}] = Monitoring.list_monitor_logs(monitor.id)
    end
  end

  describe "perform/1 logging on keyword failure" do
    setup %{monitor: monitor} do
      stub_response(%{message: "failure"}, 200)
      :ok = perform_job(HTTPCheck, job_args(monitor))
    end

    test "records keyword validation error message", %{monitor: monitor} do
      assert [%{error_message: "Keyword validation failed"}] =
               Monitoring.list_monitor_logs(monitor.id)
    end
  end

  describe "perform/1 logging on network failure" do
    setup %{monitor: monitor} do
      expect(MonitorClientMock, :request, fn _opts ->
        {:error, %RuntimeError{message: "timeout"}}
      end)

      :ok = perform_job(HTTPCheck, job_args(monitor))
    end

    test "records the exception message in log", %{monitor: monitor} do
      assert [%{error_message: "timeout"}] = Monitoring.list_monitor_logs(monitor.id)
    end
  end

  describe "perform/1 logging on health status change" do
    setup %{monitor: monitor} do
      expect(MonitorClientMock, :request, fn _opts ->
        {:ok, %Req.Response{status: 200, body: "response has failure in it"}}
      end)

      :ok = perform_job(HTTPCheck, job_args(monitor))
    end

    test "records a response snippet", %{monitor: monitor} do
      assert [%{response_snippet: snippet}] = Monitoring.list_monitor_logs(monitor.id)
      assert snippet =~ "failure"
    end
  end

  defp stub_response(body, status) do
    expect(MonitorClientMock, :request, fn _opts ->
      {:ok, %Req.Response{status: status, body: body}}
    end)
  end

  defp job_args(monitor), do: %{"id" => monitor.id, "client_name" => "mock"}

  defp current_status(monitor) do
    Monitoring.get_monitor!(monitor.id).health_status
  end
end
