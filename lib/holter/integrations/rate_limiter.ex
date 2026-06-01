defmodule Holter.Integrations.RateLimiter do
  @moduledoc false

  use Hammer, backend: :ets

  @doc """
  Checks whether the given integration may perform an outbound call.
  Hits the per-provider bucket and returns `:ok` or `{:error, :rate_limited}`.
  """
  @spec check_rate(binary(), atom()) :: :ok | {:error, :rate_limited}
  def check_rate(integration_id, provider) do
    {scale_ms, limit} = bucket_for(provider)
    key = "integration:#{integration_id}:#{provider}"

    case hit(key, scale_ms, limit) do
      {:allow, _count} -> :ok
      {:deny, _limit} -> {:error, :rate_limited}
    end
  end

  defp bucket_for(provider) do
    limits = Application.get_env(:holter, :integration_rate_limits, %{})
    Map.get(limits, provider, {86_400_000, 10_000})
  end
end
