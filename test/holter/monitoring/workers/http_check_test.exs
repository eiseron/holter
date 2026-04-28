defmodule Holter.Monitoring.Workers.HTTPCheckTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo
  import Mox

  alias Holter.Monitoring
  alias Holter.Monitoring.MonitorClientMock
  alias Holter.Monitoring.Workers.HTTPCheck

  @monitor_attrs %{
    url: "https://test.local",
    method: :get,
    interval_seconds: 60,
    logical_state: :active,
    raw_keyword_positive: "success",
    raw_keyword_negative: "error",
    health_status: :up
  }

  setup do
    monitor = monitor_fixture(@monitor_attrs)
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

    test "sets health_status to :compromised", %{monitor: monitor} do
      assert current_status(monitor) == :compromised
    end
  end

  describe "perform/1 logging on successful check" do
    setup %{monitor: monitor} do
      stub_response(%{message: "success"}, 200)
      :ok = perform_job(HTTPCheck, job_args(monitor))
    end

    test "records :up status in log", %{monitor: monitor} do
      assert [%{status: :up}] = Monitoring.list_monitor_logs(monitor, %{}).logs
    end

    test "records HTTP status code in log", %{monitor: monitor} do
      assert [%{status_code: 200}] = Monitoring.list_monitor_logs(monitor, %{}).logs
    end
  end

  describe "perform/1 logging on missing keyword failure" do
    setup %{monitor: monitor} do
      stub_response(%{message: "failure"}, 200)
      :ok = perform_job(HTTPCheck, job_args(monitor))
    end

    test "records keyword validation error message including the missing keyword name", %{
      monitor: monitor
    } do
      assert [%{error_message: "Missing required keywords: \"success\""}] =
               Monitoring.list_monitor_logs(monitor, %{}).logs
    end
  end

  describe "perform/1 logging on negative keyword failure" do
    setup %{monitor: monitor} do
      stub_response("success but has error", 200)
      :ok = perform_job(HTTPCheck, job_args(monitor))
    end

    test "records forbidden keyword error message including the matched keyword name", %{
      monitor: monitor
    } do
      assert [%{error_message: "Found forbidden keywords: \"error\""}] =
               Monitoring.list_monitor_logs(monitor, %{}).logs
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
      assert [%{error_message: "timeout"}] = Monitoring.list_monitor_logs(monitor, %{}).logs
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
      assert [%{response_snippet: snippet}] = Monitoring.list_monitor_logs(monitor, %{}).logs
      assert snippet =~ "failure"
    end
  end

  describe "perform/1 with ssl_ignore enabled" do
    setup %{monitor: monitor} do
      {:ok, monitor} = Monitoring.update_monitor(monitor, %{ssl_ignore: true})

      expect(MonitorClientMock, :request, fn opts ->
        assert opts[:connect_options][:transport_opts][:verify] == :verify_none
        {:ok, %Req.Response{status: 200, body: "success"}}
      end)

      :ok = perform_job(HTTPCheck, job_args(monitor))
    end

    test "passes verify_none to the client", %{monitor: monitor} do
      assert current_status(monitor) == :up
    end
  end

  describe "perform/1 with follow_redirects enabled" do
    test "follows a single redirect", %{monitor: monitor} do
      {:ok, monitor} = Monitoring.update_monitor(monitor, %{follow_redirects: true})

      expect(MonitorClientMock, :request, fn opts ->
        assert opts[:url] == "https://1.2.3.4"

        {:ok,
         %Req.Response{
           status: 301,
           headers: [{"location", "https://redirected.local"}],
           body: ""
         }}
      end)

      expect(MonitorClientMock, :request, fn opts ->
        assert opts[:url] == "https://1.2.3.4"
        {:ok, %Req.Response{status: 200, body: "success"}}
      end)

      :ok = perform_job(HTTPCheck, job_args(monitor))
      assert current_status(monitor) == :up

      assert [%{redirect_count: 1, last_redirect_url: "https://redirected.local"}] =
               Monitoring.list_monitor_logs(monitor, %{}).logs
    end

    test "follows multiple redirects up to max_redirects", %{monitor: monitor} do
      {:ok, monitor} =
        Monitoring.update_monitor(monitor, %{follow_redirects: true, max_redirects: 2})

      expect(MonitorClientMock, :request, fn _opts ->
        {:ok, %Req.Response{status: 301, headers: [{"location", "/1"}], body: ""}}
      end)

      expect(MonitorClientMock, :request, fn _opts ->
        {:ok, %Req.Response{status: 301, headers: [{"location", "/2"}], body: ""}}
      end)

      expect(MonitorClientMock, :request, fn _opts ->
        {:ok, %Req.Response{status: 200, body: "success"}}
      end)

      :ok = perform_job(HTTPCheck, job_args(monitor))
      assert current_status(monitor) == :up

      assert [%{redirect_count: 2, last_redirect_url: "https://test.local/2"}] =
               Monitoring.list_monitor_logs(monitor, %{}).logs
    end

    test "stops at max_redirects", %{monitor: monitor} do
      {:ok, monitor} =
        Monitoring.update_monitor(monitor, %{follow_redirects: true, max_redirects: 1})

      expect(MonitorClientMock, :request, fn _opts ->
        {:ok, %Req.Response{status: 301, headers: [{"location", "/1"}], body: ""}}
      end)

      expect(MonitorClientMock, :request, fn _opts ->
        {:ok, %Req.Response{status: 301, headers: [{"location", "/2"}], body: ""}}
      end)

      :ok = perform_job(HTTPCheck, job_args(monitor))

      assert current_status(monitor) == :down

      assert [%{redirect_count: 1, last_redirect_url: "https://test.local/1", status_code: 301}] =
               Monitoring.list_monitor_logs(monitor, %{}).logs
    end

    test "handles circular redirects", %{monitor: monitor} do
      {:ok, monitor} =
        Monitoring.update_monitor(monitor, %{follow_redirects: true, max_redirects: 5})

      expect(MonitorClientMock, :request, 6, fn opts ->
        location = if String.ends_with?(opts[:url], "A"), do: "/B", else: "/A"
        {:ok, %Req.Response{status: 302, headers: [{"location", location}], body: ""}}
      end)

      :ok = perform_job(HTTPCheck, job_args(monitor))
      assert current_status(monitor) == :down

      assert [%{redirect_count: 5, status_code: 302}] =
               Monitoring.list_monitor_logs(monitor, %{}).logs
    end
  end

  describe "redirect_list with a two-hop chain" do
    setup %{monitor: monitor} do
      {:ok, monitor} =
        Monitoring.update_monitor(monitor, %{follow_redirects: true, max_redirects: 3})

      expect(MonitorClientMock, :request, fn _opts ->
        {:ok, %Req.Response{status: 301, headers: [{"location", "/hop1"}], body: ""}}
      end)

      expect(MonitorClientMock, :request, fn _opts ->
        {:ok, %Req.Response{status: 302, headers: [{"location", "/hop2"}], body: ""}}
      end)

      expect(MonitorClientMock, :request, fn _opts ->
        {:ok, %Req.Response{status: 200, body: "success"}}
      end)

      :ok = perform_job(HTTPCheck, job_args(monitor))

      [%{redirect_list: redirect_list}] = Monitoring.list_monitor_logs(monitor, %{}).logs
      [hop1, hop2, hop3] = redirect_list

      %{redirect_list: redirect_list, hop1: hop1, hop2: hop2, hop3: hop3}
    end

    test "records three entries in redirect_list", %{redirect_list: redirect_list} do
      assert length(redirect_list) == 3
    end

    test "hop 1 url is the origin", %{hop1: hop1} do
      assert hop1["url"] =~ "test.local"
    end

    test "hop 1 status_code is 301", %{hop1: hop1} do
      assert hop1["status_code"] == 301
    end

    test "hop 1 ip is a string", %{hop1: hop1} do
      assert is_binary(hop1["ip"])
    end

    test "hop 2 url is the first redirect destination", %{hop2: hop2} do
      assert hop2["url"] =~ "/hop1"
    end

    test "hop 2 status_code is 302", %{hop2: hop2} do
      assert hop2["status_code"] == 302
    end

    test "hop 2 ip is a string", %{hop2: hop2} do
      assert is_binary(hop2["ip"])
    end

    test "hop 3 url is the second redirect destination", %{hop3: hop3} do
      assert hop3["url"] =~ "/hop2"
    end

    test "hop 3 status_code is 200", %{hop3: hop3} do
      assert hop3["status_code"] == 200
    end

    test "hop 3 ip is a string", %{hop3: hop3} do
      assert is_binary(hop3["ip"])
    end

    test "hop 1 latency_ms is an integer", %{hop1: hop1} do
      assert is_integer(hop1["latency_ms"])
    end

    test "hop 2 latency_ms is an integer", %{hop2: hop2} do
      assert is_integer(hop2["latency_ms"])
    end

    test "hop 3 latency_ms is an integer", %{hop3: hop3} do
      assert is_integer(hop3["latency_ms"])
    end
  end

  describe "redirect_list when no redirects occur" do
    setup %{monitor: monitor} do
      stub_response("success", 200)
      :ok = perform_job(HTTPCheck, job_args(monitor))

      [%{redirect_count: redirect_count, redirect_list: [hop]}] =
        Monitoring.list_monitor_logs(monitor, %{}).logs

      %{hop: hop, monitor: monitor, redirect_count: redirect_count}
    end

    test "redirect_count is zero", %{redirect_count: redirect_count} do
      assert redirect_count == 0
    end

    test "origin hop url matches monitor url", %{hop: hop, monitor: monitor} do
      assert hop["url"] == monitor.url
    end

    test "origin hop status_code is 200", %{hop: hop} do
      assert hop["status_code"] == 200
    end

    test "origin hop ip is a string", %{hop: hop} do
      assert is_binary(hop["ip"])
    end

    test "origin hop latency_ms is an integer", %{hop: hop} do
      assert is_integer(hop["latency_ms"])
    end
  end

  describe "perform/1 logging on socket closed error" do
    setup %{monitor: monitor} do
      expect(MonitorClientMock, :request, fn _opts ->
        {:error, %Mint.TransportError{reason: :closed}}
      end)

      :ok = perform_job(HTTPCheck, job_args(monitor))
    end

    test "records :down status", %{monitor: monitor} do
      assert [%{status: :down}] = Monitoring.list_monitor_logs(monitor, %{}).logs
    end

    test "records socket closed in error_message", %{monitor: monitor} do
      assert [%{error_message: msg}] = Monitoring.list_monitor_logs(monitor, %{}).logs
      assert msg =~ "closed"
    end

    test "records nil status_code", %{monitor: monitor} do
      assert [%{status_code: nil}] = Monitoring.list_monitor_logs(monitor, %{}).logs
    end
  end

  defp stub_response(body, status) do
    expect(MonitorClientMock, :request, fn _opts ->
      {:ok, %Req.Response{status: status, body: body}}
    end)
  end

  defp job_args(monitor), do: %{"id" => monitor.id}

  defp current_status(monitor) do
    Monitoring.get_monitor!(monitor.id).health_status
  end
end
