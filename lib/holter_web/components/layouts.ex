defmodule HolterWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use HolterWeb, :html

  embed_templates "layouts/*"

  def app_config_json do
    %{
      i18n: %{
        unsaved_confirm: gettext("You have unsaved changes. Leave without saving?")
      }
    }
    |> Jason.encode!()
    |> String.replace("</", "<\\/")
    |> Phoenix.HTML.raw()
  end
end
