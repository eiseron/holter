defmodule Holter.SentryFinchClient do
  @moduledoc false
  @behaviour Sentry.HTTPClient

  @pool_name __MODULE__

  @impl Sentry.HTTPClient
  def child_spec, do: Finch.child_spec(name: @pool_name)

  @impl Sentry.HTTPClient
  def post(url, headers, body) do
    request = Finch.build(:post, url, headers, body)

    case Finch.request(request, @pool_name) do
      {:ok, %Finch.Response{status: status, headers: resp_headers, body: resp_body}} ->
        {:ok, status, resp_headers, resp_body}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
