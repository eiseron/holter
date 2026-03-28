defmodule Holter.Test.DummyService do
  @moduledoc """
  Local HTTP test server backed by a FIFO queue per `call_id`.

  Responses are dequeued in registration order. Sending the same `call_id`
  multiple times allows modelling distinct responses per consecutive request,
  independent of any domain concept such as a monitor ID.

  ## Usage

      DummyService.enqueue("mycheck", status: 500, body: "Error")
      DummyService.enqueue("mycheck", status: 200, body: "OK")

      # GET /probe/mycheck -> 500 (first call)
      # GET /probe/mycheck -> 200 (second call)
      # GET /probe/mycheck -> 404 (queue exhausted)
  """
  use Plug.Router

  plug :match
  plug :dispatch

  @agent __MODULE__.State

  def start_link(_opts), do: Agent.start_link(fn -> %{} end, name: @agent)

  def enqueue(call_id, response_attrs) do
    Agent.update(@agent, fn state ->
      Map.update(state, to_string(call_id), [response_attrs], &(&1 ++ [response_attrs]))
    end)
  end

  def reset, do: Agent.update(@agent, fn _ -> %{} end)

  get "/probe/:call_id" do
    case dequeue(call_id) do
      :empty ->
        send_resp(conn, 404, "No responses queued for: #{call_id}")

      attrs ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(Keyword.get(attrs, :status, 200), Keyword.get(attrs, :body, "OK"))
    end
  end

  match(_, do: send_resp(conn, 404, "Not Found: #{conn.request_path}"))

  defp dequeue(call_id) do
    Agent.get_and_update(@agent, fn state ->
      case Map.get(state, call_id, []) do
        [] -> {:empty, state}
        [next | rest] -> {next, Map.put(state, call_id, rest)}
      end
    end)
  end
end
