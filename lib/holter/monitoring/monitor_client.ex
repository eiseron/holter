defmodule Holter.Monitoring.MonitorClient do
  @moduledoc """
  Behaviour for the HTTP client used by the monitoring engine.
  """

  @callback request(keyword()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}

  defmodule HTTP do
    @moduledoc """
    Default HTTP implementation using Req.
    """
    @behaviour Holter.Monitoring.MonitorClient

    @impl true
    def request(opts) do
      opts
      |> Keyword.put_new(:retry, false)
      |> Req.request()
    end
  end
end
