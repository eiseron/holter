defmodule Holter.Test.DummyService do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  def enqueue(call_id, opts) do
    Agent.update(__MODULE__, fn state ->
      responses = Map.get(state, call_id, [])
      Map.put(state, call_id, responses ++ [opts])
    end)
  end

  def reset do
    Agent.update(__MODULE__, fn _ -> %{} end)
  end

  get "/probe/:call_id" do
    state = Agent.get(__MODULE__, & &1)

    case Map.get(state, call_id) do
      [next | rest] ->
        Agent.update(__MODULE__, &Map.put(&1, call_id, rest))
        status = Keyword.get(next, :status, 200)
        body = Keyword.get(next, :body, "OK")
        send_resp(conn, status, body)

      _ ->
        send_resp(conn, 404, "No responses queued for: #{call_id}")
    end
  end

  match(_, do: send_resp(conn, 404, "Not Found: #{conn.request_path}"))

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end
end
