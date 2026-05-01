defmodule HolterWeb.HealthController do
  use HolterWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
