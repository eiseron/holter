defmodule HolterWeb.Plugs.LocalePlugTest do
  use HolterWeb.ConnCase, async: true

  @moduletag :guest

  alias Eiseron.I18n.Locale
  alias HolterWeb.Plugs.LocalePlug

  defp build_request(query \\ "", opts \\ []) do
    headers = Keyword.get(opts, :headers, [])
    workspace = Keyword.get(opts, :workspace)

    conn =
      build_conn(:get, "/" <> query)
      |> Plug.Conn.fetch_query_params()
      |> Plug.Test.init_test_session(%{})

    conn =
      Enum.reduce(headers, conn, fn {k, v}, acc -> Plug.Conn.put_req_header(acc, k, v) end)

    if workspace, do: Plug.Conn.assign(conn, :current_workspace, workspace), else: conn
  end

  describe "init/1" do
    test "returns opts unchanged" do
      assert LocalePlug.init(foo: :bar) == [foo: :bar]
    end
  end

  describe "call/2 — tier resolution" do
    test "URL param wins over Accept-Language" do
      conn =
        build_request("?locale=en", headers: [{"accept-language", "pt-BR"}])
        |> LocalePlug.call([])

      assert conn.assigns.current_locale == "en"
    end

    test "URL param wins over workspace default" do
      conn =
        build_request("?locale=en", workspace: %{default_locale: "pt_BR"})
        |> LocalePlug.call([])

      assert conn.assigns.current_locale == "en"
    end

    test "workspace default wins over Accept-Language" do
      conn =
        build_request("",
          workspace: %{default_locale: "en"},
          headers: [{"accept-language", "pt-BR"}]
        )
        |> LocalePlug.call([])

      assert conn.assigns.current_locale == "en"
    end

    test "Accept-Language is used when no other tier matches" do
      conn =
        build_request("", headers: [{"accept-language", "pt-BR"}])
        |> LocalePlug.call([])

      assert conn.assigns.current_locale == "pt_BR"
    end

    test "falls back to the configured default when no input is supplied" do
      conn = build_request() |> LocalePlug.call([])

      assert conn.assigns.current_locale == Locale.default()
    end
  end

  describe "call/2 — invalid values fall through" do
    test "an unsupported URL param falls through to Accept-Language" do
      conn =
        build_request("?locale=klingon", headers: [{"accept-language", "pt-BR"}])
        |> LocalePlug.call([])

      assert conn.assigns.current_locale == "pt_BR"
    end

    test "an unsupported workspace default falls through" do
      conn =
        build_request("",
          workspace: %{default_locale: "klingon"},
          headers: [{"accept-language", "pt-BR"}]
        )
        |> LocalePlug.call([])

      assert conn.assigns.current_locale == "pt_BR"
    end
  end

  describe "call/2 — side effects" do
    test "calls Gettext.put_locale with the resolved value" do
      build_request("?locale=en") |> LocalePlug.call([])

      assert Gettext.get_locale(HolterWeb.Gettext) == "en"
    end

    test "stamps the Accept-Language header into the session for downstream LV use" do
      conn =
        build_request("", headers: [{"accept-language", "pt-BR;q=0.9, en;q=0.5"}])
        |> LocalePlug.call([])

      assert Plug.Conn.get_session(conn, "accept_language") == "pt-BR;q=0.9, en;q=0.5"
    end
  end
end
