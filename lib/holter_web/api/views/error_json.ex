defmodule HolterWeb.Api.ErrorJSON do
  @moduledoc """
  This module is invoked by the API fallback controller for JSON error responses.
  """

  def render(template, _assigns) do
    %{
      error: %{
        code: template_to_code(template),
        message: Phoenix.Controller.status_message_from_template(template)
      }
    }
  end

  defp template_to_code("404.json"), do: "not_found"
  defp template_to_code("403.json"), do: "forbidden"
  defp template_to_code("401.json"), do: "unauthorized"
  defp template_to_code("422.json"), do: "validation_failed"
  defp template_to_code("500.json"), do: "internal_server_error"

  defp template_to_code(template),
    do: template |> String.replace(".json", "") |> String.replace(~r/[^\w]/, "_")
end
