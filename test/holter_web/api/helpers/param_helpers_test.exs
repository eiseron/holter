defmodule HolterWeb.Api.ParamHelpersTest do
  use ExUnit.Case, async: true

  import HolterWeb.Api.ParamHelpers

  describe "maybe_put_integer/4" do
    test "puts integer parsed from binary string" do
      assert maybe_put_integer(%{}, %{"page" => "5"}, "page", :page) == %{page: 5}
    end

    test "puts integer when value is already an integer" do
      assert maybe_put_integer(%{}, %{"page" => 5}, "page", :page) == %{page: 5}
    end

    test "skips non-numeric string" do
      assert maybe_put_integer(%{}, %{"page" => "abc"}, "page", :page) == %{}
    end

    test "skips string with trailing non-numeric chars" do
      assert maybe_put_integer(%{}, %{"page" => "5x"}, "page", :page) == %{}
    end

    test "skips SQL injection attempt" do
      assert maybe_put_integer(%{}, %{"page" => "1 UNION SELECT *"}, "page", :page) == %{}
    end

    test "skips missing key" do
      assert maybe_put_integer(%{}, %{}, "page", :page) == %{}
    end

    test "skips nil value" do
      assert maybe_put_integer(%{}, %{"page" => nil}, "page", :page) == %{}
    end

    test "preserves existing accumulator entries" do
      result = maybe_put_integer(%{sort_by: "date"}, %{"page" => "2"}, "page", :page)
      assert result == %{sort_by: "date", page: 2}
    end

    test "overwrites existing key in accumulator" do
      result = maybe_put_integer(%{page: 1}, %{"page" => "3"}, "page", :page)
      assert result == %{page: 3}
    end
  end

  describe "maybe_put_string/4" do
    test "puts non-empty binary string" do
      assert maybe_put_string(%{}, %{"sort_dir" => "asc"}, "sort_dir", :sort_dir) ==
               %{sort_dir: "asc"}
    end

    test "skips empty string" do
      assert maybe_put_string(%{}, %{"sort_dir" => ""}, "sort_dir", :sort_dir) == %{}
    end

    test "skips missing key" do
      assert maybe_put_string(%{}, %{}, "sort_dir", :sort_dir) == %{}
    end

    test "skips nil value" do
      assert maybe_put_string(%{}, %{"sort_dir" => nil}, "sort_dir", :sort_dir) == %{}
    end

    test "skips integer value" do
      assert maybe_put_string(%{}, %{"sort_dir" => 42}, "sort_dir", :sort_dir) == %{}
    end

    test "preserves existing accumulator entries" do
      result = maybe_put_string(%{page: 1}, %{"sort_dir" => "desc"}, "sort_dir", :sort_dir)
      assert result == %{page: 1, sort_dir: "desc"}
    end

    test "accepts SQL injection string as-is (caller whitelist is responsible for safety)" do
      val = "asc; DROP TABLE users--"

      result = maybe_put_string(%{}, %{"sort_dir" => val}, "sort_dir", :sort_dir)
      assert result == %{sort_dir: val}
    end
  end
end
