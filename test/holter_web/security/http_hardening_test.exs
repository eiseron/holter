defmodule HolterWeb.Security.HttpHardeningTest do
  use HolterWeb.ConnCase, async: true

  describe "security headers on browser routes" do
    test "sets x-content-type-options to nosniff" do
      conn = get(build_conn(), ~p"/identity/login")
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "sets content-security-policy with frame-ancestors" do
      conn = get(build_conn(), ~p"/identity/login")
      [csp] = get_resp_header(conn, "content-security-policy")
      assert csp =~ "frame-ancestors"
    end

    test "sets referrer-policy" do
      conn = get(build_conn(), ~p"/identity/login")
      assert get_resp_header(conn, "referrer-policy") != []
    end

    test "sets x-permitted-cross-domain-policies to none" do
      conn = get(build_conn(), ~p"/identity/login")
      assert get_resp_header(conn, "x-permitted-cross-domain-policies") == ["none"]
    end

    test "does not expose server header" do
      conn = get(build_conn(), ~p"/identity/login")
      assert get_resp_header(conn, "server") == []
    end

    test "does not expose x-powered-by header" do
      conn = get(build_conn(), ~p"/identity/login")
      assert get_resp_header(conn, "x-powered-by") == []
    end
  end

  describe "session cookie flags" do
    test "session cookie is HttpOnly" do
      conn = get(build_conn(), ~p"/identity/login")

      cookie =
        get_resp_header(conn, "set-cookie")
        |> Enum.find(&String.contains?(&1, "_holter_key"))

      assert String.contains?(cookie || "", "HttpOnly")
    end

    test "session cookie has SameSite attribute" do
      conn = get(build_conn(), ~p"/identity/login")

      cookie =
        get_resp_header(conn, "set-cookie")
        |> Enum.find(&String.contains?(&1, "_holter_key"))

      assert String.contains?(cookie || "", "SameSite")
    end
  end

  describe "CORS does not allow arbitrary origins" do
    test "does not reflect arbitrary origin or set wildcard CORS" do
      conn =
        build_conn()
        |> put_req_header("origin", "https://evil.example.com")
        |> get(~p"/identity/login")

      assert get_resp_header(conn, "access-control-allow-origin") == []
    end
  end
end
