defmodule Holter.Test.DummyService do
  @moduledoc """
  A simple HTTP server for integration testing.

  ## Usage

      DummyService.reset()

      DummyService.enqueue("mycheck", status: 500, body: "Error")
      DummyService.enqueue("mycheck", status: 200, body: "OK")

  """
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  def enqueue(call_id, opts) do
    Agent.update(__MODULE__, fn state ->
      responses = Map.get(state.responses, call_id, [])
      %{state | responses: Map.put(state.responses, call_id, responses ++ [opts])}
    end)
  end

  def get_requests do
    Agent.get(__MODULE__, & &1.requests)
  end

  def reset do
    Agent.update(__MODULE__, fn _ -> %{responses: %{}, requests: []} end)
  end

  def start_link(_) do
    Agent.start_link(fn -> %{responses: %{}, requests: []} end, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  get "/probe/:call_id" do
    dispatch_probe(conn, call_id)
  end

  post "/probe/:call_id" do
    dispatch_probe(conn, call_id)
  end

  match(_, do: send_resp(conn, 404, "Not Found: #{conn.request_path}"))

  defp dispatch_probe(conn, call_id) do
    Agent.update(__MODULE__, fn state ->
      %{state | requests: state.requests ++ [conn]}
    end)

    state = Agent.get(__MODULE__, & &1)

    case Map.get(state.responses, call_id) do
      [next | rest] ->
        Agent.update(__MODULE__, fn state ->
          %{state | responses: Map.put(state.responses, call_id, rest)}
        end)

        status = Keyword.get(next, :status, 200)
        body = Keyword.get(next, :body, "OK")
        headers = Keyword.get(next, :headers, [])
        delay = Keyword.get(next, :delay, 0)

        if delay > 0, do: Process.sleep(delay)

        conn
        |> merge_resp_headers(headers)
        |> send_resp(status, body)

      _ ->
        send_resp(conn, 404, "No responses queued for: #{call_id}")
    end
  end
end
