defmodule HolterWeb.Api.ErrorJSONTest do
  use HolterWeb.ConnCase, async: true

  alias HolterWeb.Api.ErrorJSON

  test "renders 404" do
    assert ErrorJSON.render("404.json", %{}) == %{
             error: %{code: "not_found", message: "Not Found"}
           }
  end

  test "renders 500" do
    assert ErrorJSON.render("500.json", %{}) == %{
             error: %{code: "internal_server_error", message: "Internal Server Error"}
           }
  end
end
