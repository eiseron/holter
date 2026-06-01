defmodule Holter.Integrations.Engine.ErrorClassifier do
  @moduledoc false

  @spec classify_error(atom(), term()) :: error_class()
  def classify_error(_provider, {:status, 401, _}), do: :token_expired
  def classify_error(_provider, {:status, 403, _}), do: :revoked
  def classify_error(_provider, {:status, 429, _}), do: :rate_limited
  def classify_error(_provider, {:status, status, _}) when status in 500..599, do: :provider_down
  def classify_error(_provider, :unauthorized), do: :token_expired
  def classify_error(_provider, :revoked), do: :revoked
  def classify_error(_provider, :rate_limited), do: :rate_limited
  def classify_error(_provider, :provider_down), do: :provider_down
  def classify_error(_provider, _reason), do: :invalid_payload

  @spec build_error_update_attrs(error_class(), %{reason: term(), now: DateTime.t()}) :: map()
  def build_error_update_attrs(:revoked, %{now: now}) do
    %{status: :reauth_required, last_error_at: now, last_error_reason: "token_revoked"}
  end

  def build_error_update_attrs(:rate_limited, %{now: now}) do
    %{status: :rate_limited, last_error_at: now, last_error_reason: "rate_limited"}
  end

  def build_error_update_attrs(:provider_down, %{reason: reason, now: now}) do
    %{status: :provider_down, last_error_at: now, last_error_reason: inspect(reason)}
  end

  def build_error_update_attrs(_other, _context), do: %{}

  @spec determine_retry_strategy(error_class()) ::
          {:error, binary()} | {:discard, binary()} | {:snooze, non_neg_integer()}
  def determine_retry_strategy(:token_expired), do: {:error, "token_expired"}
  def determine_retry_strategy(:revoked), do: {:discard, "token_revoked"}
  def determine_retry_strategy(:rate_limited), do: {:snooze, 60}
  def determine_retry_strategy(:provider_down), do: {:snooze, 300}
  def determine_retry_strategy(:invalid_payload), do: {:discard, "invalid_payload"}
  def determine_retry_strategy(_other), do: {:discard, "unknown_error"}

  @type error_class ::
          :token_expired | :revoked | :rate_limited | :provider_down | :invalid_payload
end
