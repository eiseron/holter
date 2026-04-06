defmodule HolterWeb.Api.ErrorJSON do
  @moduledoc """
  This module is invoked by the API fallback controller for JSON error responses.
  """

  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
