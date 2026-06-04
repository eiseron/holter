defmodule Holter.Integrations.Meta.Ads.RequestBuilder do
  @moduledoc """
  Builds the outbound Meta Ads Graph status request.

  Campaigns and ad sets are addressed identically through the Graph API,
  so the `encode/3` clauses differ only by the target status. Holds the
  object-id validation (the path-injection guard), URL, and body.
  """

  @object_id_format ~r/^\d+$/

  @spec build(String.t(), String.t(), term()) ::
          {:ok, Holter.Integrations.Request.t()} | {:error, :invalid_target_id}
  def build(object_id, status, integration) do
    access_token = Map.get(integration.credentials_encrypted || %{}, "access_token", "")

    case parse_object_id(object_id) do
      {:ok, object_id} ->
        {:ok,
         %Holter.Integrations.Request{
           method: :post,
           url: build_api_url(object_id),
           headers: [{"content-type", "application/x-www-form-urlencoded"}],
           body: build_status_body(object_id, access_token, status)
         }}

      {:error, :invalid_target_id} ->
        {:error, :invalid_target_id}
    end
  end

  defp build_status_body(object_id, access_token, status) do
    %{
      "id" => object_id,
      "access_token" => access_token,
      "status" => status
    }
  end

  defp build_api_url(object_id) do
    "https://graph.facebook.com/#{api_version()}/#{object_id}"
  end

  defp api_version do
    :holter
    |> Application.get_env(:meta_ads, [])
    |> Keyword.get(:api_version, "v25.0")
  end

  defp parse_object_id(object_id) when is_binary(object_id) do
    if Regex.match?(@object_id_format, object_id) do
      {:ok, object_id}
    else
      {:error, :invalid_target_id}
    end
  end

  defp parse_object_id(_object_id), do: {:error, :invalid_target_id}
end
