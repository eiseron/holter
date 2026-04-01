defmodule Holter.Monitoring.EngineTest do
  use Holter.DataCase, async: true
  alias Holter.Monitoring.Engine
  alias Holter.Monitoring

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

  describe "process_response/3 with 200 OK and matching keyword" do
    setup %{monitor: monitor} do
      :ok = Engine.process_response(monitor, ok_response("Everything is a success!"), 100)
    end

    test "sets health_status to :up", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :up
    end
  end

  describe "process_response/3 with HTTP 500" do
    setup %{monitor: monitor} do
      :ok = Engine.process_response(monitor, error_response(500, "Internal Error"), 100)
    end

    test "sets health_status to :down", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :down
    end

    test "opens a downtime incident", %{monitor: monitor} do
      assert Monitoring.get_open_incident(monitor.id)
    end

    test "sets the incident root_cause from the HTTP status", %{monitor: monitor} do
      assert %{root_cause: "HTTP Error: 500"} = Monitoring.get_open_incident(monitor.id)
    end
  end

  describe "process_response/3 with missing positive keyword" do
    setup %{monitor: monitor} do
      :ok = Engine.process_response(monitor, ok_response("No match here"), 100)
    end

    test "sets health_status to :down", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :down
    end

    test "opens a downtime incident", %{monitor: monitor} do
      assert Monitoring.get_open_incident(monitor.id)
    end

    test "sets root_cause to keyword validation failure", %{monitor: monitor} do
      assert %{root_cause: "Keyword validation failed"} = Monitoring.get_open_incident(monitor.id)
    end
  end

  describe "process_response/3 with negative keyword present" do
    setup %{monitor: monitor} do
      :ok = Engine.process_response(monitor, ok_response("success but has an error"), 100)
    end

    test "sets health_status to :down", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :down
    end

    test "sets root_cause to keyword validation failure", %{monitor: monitor} do
      assert %{root_cause: "Keyword validation failed"} = Monitoring.get_open_incident(monitor.id)
    end
  end

  describe "process_response/3 on recovery after downtime" do
    setup %{monitor: monitor} do
      :ok = Engine.process_response(monitor, error_response(500, ""), 100)
      monitor = Monitoring.get_monitor!(monitor.id)
      monitor = %{monitor | keyword_positive: ["success"], keyword_negative: []}
      :ok = Engine.process_response(monitor, ok_response("Everything is success"), 100)
    end

    test "sets health_status to :up", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :up
    end

    test "closes the open incident", %{monitor: monitor} do
      assert is_nil(Monitoring.get_open_incident(monitor.id))
    end
  end

  describe "handle_failure/3 on network error" do
    setup %{monitor: monitor} do
      :ok = Engine.handle_failure(monitor, %RuntimeError{message: "connection refused"}, 50)
    end

    test "sets health_status to :down", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :down
    end

    test "records the exception message in the log", %{monitor: monitor} do
      assert [%{error_message: "connection refused"}] = Monitoring.list_monitor_logs(monitor.id)
    end
  end

  defp ok_response(body), do: %Req.Response{status: 200, body: body}
  defp error_response(status, body), do: %Req.Response{status: status, body: body}
end
