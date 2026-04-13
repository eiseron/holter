defmodule HolterWeb.Api.ChangesetJSON do
  @moduledoc """
  JSON view for rendering Ecto.Changeset errors.
  """

  @doc """
  Renders changeset errors.
  """
  def error(%{changeset: changeset}) do
    %{
      error: %{
        code: "validation_failed",
        message: "The provided parameters are invalid.",
        details: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
      }
    }
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
