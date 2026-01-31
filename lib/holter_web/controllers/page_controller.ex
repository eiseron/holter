defmodule HolterWeb.PageController do
  use HolterWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
