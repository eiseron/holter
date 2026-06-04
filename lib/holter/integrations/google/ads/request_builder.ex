defmodule Holter.Integrations.Google.Ads.RequestBuilder do
  @moduledoc """
  Builds the outbound Google Ads campaign mutate request.

  Holds the shared mechanics the `encode/3` clauses reuse: customer-id
  validation (the SSRF / path-injection guard), URL, headers, and the
  mutate body. Only the target status varies between pause and resume.
  """

  @customer_id_format ~r/^\d{10}$/

  @spec build(String.t(), String.t(), term()) ::
          {:ok, Holter.Integrations.Request.t()} | {:error, :invalid_customer_id}
  def build(campaign_id, status, integration) do
    customer_id = get_in(integration.settings, ["customer_id"]) || ""
    manager_id = get_in(integration.settings, ["manager_customer_id"])

    with {:ok, customer_id} <- parse_customer_id(customer_id),
         {:ok, manager_id} <- normalize_manager_id(manager_id) do
      {:ok,
       %Holter.Integrations.Request{
         method: :post,
         url: build_api_url(customer_id),
         headers: request_headers(integration, manager_id),
         body: build_mutation(campaign_id, customer_id, status)
       }}
    end
  end

  defp normalize_manager_id(nil), do: {:ok, nil}
  defp normalize_manager_id(manager_id), do: parse_customer_id(manager_id)

  defp build_mutation(campaign_id, customer_id, status) do
    %{
      "operations" => [
        %{
          "update" => %{
            "resourceName" => "customers/#{customer_id}/campaigns/#{campaign_id}",
            "status" => status
          },
          "updateMask" => "status"
        }
      ]
    }
  end

  defp build_api_url(customer_id) do
    "https://googleads.googleapis.com/#{api_version()}/customers/#{customer_id}/campaigns:mutate"
  end

  defp api_version do
    :holter
    |> Application.get_env(:google_ads, [])
    |> Keyword.get(:api_version, "v24")
  end

  defp request_headers(integration, manager_id) do
    access_token = Map.get(integration.credentials_encrypted || %{}, "access_token", "")

    base = [
      {"authorization", "Bearer #{access_token}"},
      {"developer-token", fetch_developer_token()},
      {"content-type", "application/json"}
    ]

    prepend_manager_header(base, manager_id)
  end

  defp prepend_manager_header(headers, nil), do: headers

  defp prepend_manager_header(headers, manager_id),
    do: [{"login-customer-id", manager_id} | headers]

  defp fetch_developer_token do
    :holter
    |> Application.get_env(:google_ads, [])
    |> Keyword.get(:developer_token, "")
  end

  defp parse_customer_id(customer_id) when is_binary(customer_id) do
    normalized = String.replace(customer_id, "-", "")

    if Regex.match?(@customer_id_format, normalized) do
      {:ok, normalized}
    else
      {:error, :invalid_customer_id}
    end
  end

  defp parse_customer_id(_customer_id), do: {:error, :invalid_customer_id}
end
