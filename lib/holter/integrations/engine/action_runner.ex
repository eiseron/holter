defmodule Holter.Integrations.Engine.ActionRunner do
  @moduledoc """
  Central effector for outbound provider actions.

  For each target it asks the provider to encode the action into a
  `Request` (`encode/3`), then performs and classifies the HTTP call once
  for every provider. Targets whose action the provider does not support
  are skipped; the loop halts on the first failure.
  """

  alias Holter.Integrations.HttpClient
  alias Holter.Integrations.Request

  @spec run(module(), term(), map()) :: :ok | {:error, term()}
  def run(provider_mod, integration, payload) do
    payload
    |> extract_targets()
    |> Enum.reduce_while(:ok, fn target, _acc -> run_target(provider_mod, integration, target) end)
  end

  defp run_target(provider_mod, integration, %{"action" => action} = target) do
    case provider_mod.encode(action, target, integration) do
      {:ok, request} -> execute(request)
      :unsupported -> {:cont, :ok}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp run_target(_provider_mod, _integration, _target), do: {:cont, :ok}

  defp execute(%Request{url: url, headers: headers, body: body}) do
    case HttpClient.impl().post(url, encode_body(body, headers), headers) do
      {:ok, %{status: status}} when status in 200..299 ->
        {:cont, :ok}

      {:ok, %{status: 429}} ->
        {:halt, {:error, :rate_limited}}

      {:ok, %{status: status, body: resp_body}} ->
        {:halt, {:error, {:http_error, status, resp_body}}}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp extract_targets(payload) when is_map(payload),
    do: Map.get(payload, "targets") || Map.get(payload, :targets) || []

  defp extract_targets(_payload), do: []

  defp encode_body(body, headers) do
    headers
    |> content_type()
    |> encode_for(body)
  end

  defp encode_for("application/x-www-form-urlencoded" <> _rest, body), do: URI.encode_query(body)
  defp encode_for(_content_type, body), do: Jason.encode!(body)

  defp content_type(headers) do
    Enum.find_value(headers, "application/json", fn {key, value} ->
      String.downcase(key) == "content-type" && value
    end)
  end
end
