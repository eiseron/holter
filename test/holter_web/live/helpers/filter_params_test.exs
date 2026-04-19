defmodule HolterWeb.LiveView.FilterParamsTest do
  use ExUnit.Case, async: true

  alias HolterWeb.LiveView.FilterParams

  @valid_keys ~w(page page_size sort_by sort_dir)

  describe "normalize/2" do
    test "converts string keys to atoms for allowed keys" do
      result = FilterParams.normalize(%{"page" => "2", "sort_by" => "date"}, @valid_keys)
      assert result == %{page: "2", sort_by: "date"}
    end

    test "excludes keys not in the valid list" do
      result = FilterParams.normalize(%{"page" => "1", "unknown" => "x"}, @valid_keys)
      assert Map.has_key?(result, :page)
      refute Map.has_key?(result, :unknown)
    end

    test "returns empty map when no keys match" do
      assert FilterParams.normalize(%{"foo" => "bar"}, @valid_keys) == %{}
    end
  end

  describe "cast_integer/3" do
    test "parses binary value to integer" do
      result = FilterParams.cast_integer(%{page: "3"}, :page, 1)
      assert result.page == 3
    end

    test "passes through integer value unchanged" do
      result = FilterParams.cast_integer(%{page: 5}, :page, 1)
      assert result.page == 5
    end

    test "uses default when value is nil" do
      result = FilterParams.cast_integer(%{page: nil}, :page, 1)
      assert result.page == 1
    end

    test "uses default when key is absent" do
      result = FilterParams.cast_integer(%{}, :page, 10)
      assert result.page == 10
    end
  end

  describe "validate_sort/3" do
    test "keeps sort_by when it is in sortable_cols" do
      filters = %{sort_by: "date", sort_dir: "asc"}
      result = FilterParams.validate_sort(filters, ~w(date name), "date")
      assert result.sort_by == "date"
    end

    test "falls back to default_col when sort_by is invalid" do
      filters = %{sort_by: "injected", sort_dir: "asc"}
      result = FilterParams.validate_sort(filters, ~w(date name), "date")
      assert result.sort_by == "date"
    end

    test "keeps sort_dir when it is asc or desc" do
      filters = %{sort_by: "date", sort_dir: "asc"}
      result = FilterParams.validate_sort(filters, ~w(date), "date")
      assert result.sort_dir == "asc"
    end

    test "falls back to desc when sort_dir is invalid" do
      filters = %{sort_by: "date", sort_dir: "injected; DROP TABLE"}
      result = FilterParams.validate_sort(filters, ~w(date), "date")
      assert result.sort_dir == "desc"
    end
  end
end
