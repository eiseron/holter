defmodule HolterWeb.LiveView.SortPaginationTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [assign: 3]
  import HolterWeb.LiveView.SortPagination

  defp socket(assigns \\ %{}) do
    Enum.reduce(assigns, %Phoenix.LiveView.Socket{}, fn {k, v}, s -> assign(s, k, v) end)
  end

  describe "encode_filters/1" do
    test "encodes atom-keyed map into sorted query string" do
      assert encode_filters(%{page: 2, sort_by: "date", sort_dir: "asc"}) ==
               "page=2&sort_by=date&sort_dir=asc"
    end

    test "encodes string-keyed map" do
      assert encode_filters(%{"page" => "3", "sort_dir" => "desc"}) == "page=3&sort_dir=desc"
    end

    test "output is sorted by key name" do
      assert encode_filters(%{sort_dir: "desc", page: 1, sort_by: "date"}) ==
               "page=1&sort_by=date&sort_dir=desc"
    end

    test "omits nil values" do
      assert encode_filters(%{page: 1, status: nil}) == "page=1"
    end

    test "omits empty string values" do
      assert encode_filters(%{page: 1, status: ""}) == "page=1"
    end

    test "omits atom :id key" do
      assert encode_filters(%{id: "abc", page: 1}) == "page=1"
    end

    test "omits string 'id' key" do
      assert encode_filters(%{"id" => "abc", "page" => "1"}) == "page=1"
    end

    test "omits atom :workspace_slug key" do
      assert encode_filters(%{workspace_slug: "my-ws", page: 1}) == "page=1"
    end

    test "omits string 'workspace_slug' key" do
      assert encode_filters(%{"workspace_slug" => "my-ws", "page" => "1"}) == "page=1"
    end

    test "returns empty string for empty map" do
      assert encode_filters(%{}) == ""
    end
  end

  describe "build_sort_col/3 — inactive column" do
    setup do
      filters = %{sort_by: "date", sort_dir: "desc", page: 1}
      %{result: build_sort_col("/metrics", filters, "uptime_percent")}
    end

    test "active is false", %{result: result} do
      assert result.active == false
    end

    test "dir is nil", %{result: result} do
      assert result.dir == nil
    end

    test "url contains the target column", %{result: result} do
      assert result.url =~ "sort_by=uptime_percent"
    end

    test "url uses desc as default direction", %{result: result} do
      assert result.url =~ "sort_dir=desc"
    end
  end

  describe "build_sort_col/3 — active column sorted desc" do
    setup do
      filters = %{sort_by: "date", sort_dir: "desc", page: 1}
      %{result: build_sort_col("/metrics", filters, "date")}
    end

    test "active is true", %{result: result} do
      assert result.active == true
    end

    test "dir is desc", %{result: result} do
      assert result.dir == "desc"
    end

    test "url toggles direction to asc", %{result: result} do
      assert result.url =~ "sort_dir=asc"
    end
  end

  describe "build_sort_col/3 — active column sorted asc" do
    setup do
      filters = %{sort_by: "date", sort_dir: "asc", page: 1}
      %{result: build_sort_col("/metrics", filters, "date")}
    end

    test "active is true", %{result: result} do
      assert result.active == true
    end

    test "dir is asc", %{result: result} do
      assert result.dir == "asc"
    end

    test "url toggles direction to desc", %{result: result} do
      assert result.url =~ "sort_dir=desc"
    end
  end

  describe "build_sort_col/3 — url properties" do
    test "toggle url resets page to 1" do
      filters = %{sort_by: "date", sort_dir: "desc", page: 5}
      result = build_sort_col("/metrics", filters, "date")
      assert result.url =~ "page=1"
    end

    test "url starts with the provided path" do
      filters = %{sort_by: "date", sort_dir: "desc", page: 1}
      result = build_sort_col("/monitoring/monitor/abc/daily_metrics", filters, "date")
      assert String.starts_with?(result.url, "/monitoring/monitor/abc/daily_metrics?")
    end
  end

  describe "assign_sort_info/4" do
    test "sets :sort_info with an entry for each sortable column" do
      filters = %{sort_by: "date", sort_dir: "desc", page: 1}
      s = socket() |> assign_sort_info("/metrics", ~w(date uptime_percent), filters)
      assert Map.keys(s.assigns.sort_info) == ["date", "uptime_percent"]
    end

    test "active column is marked active" do
      filters = %{sort_by: "date", sort_dir: "desc", page: 1}
      s = socket() |> assign_sort_info("/metrics", ~w(date uptime_percent), filters)
      assert s.assigns.sort_info["date"].active == true
    end

    test "inactive column is not marked active" do
      filters = %{sort_by: "date", sort_dir: "desc", page: 1}
      s = socket() |> assign_sort_info("/metrics", ~w(date uptime_percent), filters)
      assert s.assigns.sort_info["uptime_percent"].active == false
    end
  end

  describe "assign_page_links/3 — page 1 of 1" do
    setup do
      s =
        socket(page_number: 1, total_pages: 1)
        |> assign_page_links("/metrics", %{sort_by: "date", sort_dir: "desc"})

      %{socket: s}
    end

    test "prev_page_url is nil", %{socket: s} do
      assert s.assigns.prev_page_url == nil
    end

    test "next_page_url is nil", %{socket: s} do
      assert s.assigns.next_page_url == nil
    end

    test "page_links contains only page 1", %{socket: s} do
      assert [{1, _url}] = s.assigns.page_links
    end
  end

  describe "assign_page_links/3 — page 1 of 5" do
    setup do
      s =
        socket(page_number: 1, total_pages: 5)
        |> assign_page_links("/metrics", %{sort_by: "date", sort_dir: "desc"})

      %{socket: s}
    end

    test "prev_page_url is nil", %{socket: s} do
      assert s.assigns.prev_page_url == nil
    end

    test "next_page_url points to page 2", %{socket: s} do
      assert s.assigns.next_page_url =~ "page=2"
    end
  end

  describe "assign_page_links/3 — page 5 of 5" do
    setup do
      s =
        socket(page_number: 5, total_pages: 5)
        |> assign_page_links("/metrics", %{sort_by: "date", sort_dir: "desc"})

      %{socket: s}
    end

    test "prev_page_url points to page 4", %{socket: s} do
      assert s.assigns.prev_page_url =~ "page=4"
    end

    test "next_page_url is nil", %{socket: s} do
      assert s.assigns.next_page_url == nil
    end
  end

  describe "assign_page_links/3 — page 3 of 5" do
    setup do
      s =
        socket(page_number: 3, total_pages: 5)
        |> assign_page_links("/metrics", %{sort_by: "date", sort_dir: "desc"})

      %{socket: s}
    end

    test "prev_page_url points to page 2", %{socket: s} do
      assert s.assigns.prev_page_url =~ "page=2"
    end

    test "next_page_url points to page 4", %{socket: s} do
      assert s.assigns.next_page_url =~ "page=4"
    end
  end

  describe "assign_page_links/3 — page_links window" do
    test "window is centered on current page with ±2 range" do
      s =
        socket(page_number: 5, total_pages: 10)
        |> assign_page_links("/metrics", %{sort_by: "date", sort_dir: "desc"})

      assert Enum.map(s.assigns.page_links, fn {n, _} -> n end) == [3, 4, 5, 6, 7]
    end

    test "window is clamped at the start" do
      s =
        socket(page_number: 1, total_pages: 10)
        |> assign_page_links("/metrics", %{sort_by: "date", sort_dir: "desc"})

      assert Enum.map(s.assigns.page_links, fn {n, _} -> n end) == [1, 2, 3]
    end

    test "window is clamped at the end" do
      s =
        socket(page_number: 10, total_pages: 10)
        |> assign_page_links("/metrics", %{sort_by: "date", sort_dir: "desc"})

      assert Enum.map(s.assigns.page_links, fn {n, _} -> n end) == [8, 9, 10]
    end

    test "page link urls start with the provided path" do
      s =
        socket(page_number: 1, total_pages: 2)
        |> assign_page_links(
          "/monitoring/monitor/abc/daily_metrics",
          %{sort_by: "date", sort_dir: "desc"}
        )

      {_n, url} = hd(s.assigns.page_links)
      assert String.starts_with?(url, "/monitoring/monitor/abc/daily_metrics?")
    end
  end
end
