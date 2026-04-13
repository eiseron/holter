defmodule HolterWeb.Api.OpenApiError do
  @moduledoc """
  Custom error renderer for OpenApiSpex validation errors.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, errors) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: %{
        code: "validation_failed",
        message: "The request body does not match the API schema.",
        details: format_errors(errors)
      }
    })
  end

  defp format_errors(errors) do
    Enum.map(errors, fn error ->
      pointer = (error.path && Enum.join(error.path, "/")) || "root"
      %{"/#{pointer}" => error.reason |> to_string() |> String.replace("_", " ")}
    end)
    |> Enum.reduce(%{}, &Map.merge/2)
  end
end
