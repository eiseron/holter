defmodule Holter.Monitoring.Workers.HTTPCheckTest do
  use Holter.DataCase, async: true
  
  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.HTTPCheck

  @monitor_attrs %{
    url: "https://test.local",
    method: "GET",
    interval_seconds: 60,
    logical_state: :active,
    keyword_positive: ["success"],
    keyword_negative: ["error"]
  }

  setup do
    monitor = create_monitor()
    %{monitor: monitor}
  end

  describe "perform/1 execution status" do
    test "sets health_status to :up on 200 OK with positive keywords", %{monitor: monitor} do
      stub_json_response(%{message: "success"}, 200)

      :ok = HTTPCheck.perform(job_for(monitor))

      assert updated_status(monitor) == :up
    end

    test "sets health_status to :down when positive keyword is missing", %{monitor: monitor} do
      stub_json_response(%{message: "failure"}, 200)

      :ok = HTTPCheck.perform(job_for(monitor))

      assert updated_status(monitor) == :down
    end

    test "sets health_status to :down on negative keyword match", %{monitor: monitor} do
      stub_json_response(%{message: "success but has error"}, 200)

      :ok = HTTPCheck.perform(job_for(monitor))

      assert updated_status(monitor) == :down
    end
  end

  describe "perform/1 logging" do
    test "records monitor_log on successful check", %{monitor: monitor} do
      stub_json_response(%{message: "success"}, 200)

      :ok = HTTPCheck.perform(job_for(monitor))

      assert [log] = Monitoring.list_monitor_logs(monitor.id)
      assert log.status == :up
      assert log.http_status == 200
    end

    test "records 'Keyword validation failed' error message", %{monitor: monitor} do
      stub_json_response(%{message: "failure"}, 200)

      :ok = HTTPCheck.perform(job_for(monitor))

      assert [%{error_message: "Keyword validation failed"}] = Monitoring.list_monitor_logs(monitor.id)
    end

    test "logs exception message on network failure", %{monitor: monitor} do
      Req.Test.stub(HTTPCheck, fn _conn -> {:error, %RuntimeError{message: "timeout"}} end)

      :ok = HTTPCheck.perform(job_for(monitor))

      assert [%{error_message: "timeout"}] = Monitoring.list_monitor_logs(monitor.id)
    end
  end

  defp create_monitor do
    {:ok, monitor} = Monitoring.create_monitor(@monitor_attrs)
    monitor
  end

  defp stub_json_response(body, status) do
    Req.Test.stub(HTTPCheck, fn conn ->
      Req.Test.json(conn, body) |> Plug.Conn.put_status(status)
    end)
  end

  defp job_for(monitor), do: %Oban.Job{args: %{"id" => monitor.id}}

  defp updated_status(monitor) do
    Monitoring.get_monitor!(monitor.id).health_status
  end
end
