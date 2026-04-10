defmodule HolterWeb.Api.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for details.
  """
  use HolterWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: HolterWeb.Api.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :quota_exceeded}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{detail: "Monitor limit reached for this workspace"}})
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: HolterWeb.Api.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: HolterWeb.Api.ErrorJSON)
    |> render(:"403")
  end
end
