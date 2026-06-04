defmodule Holter.Identity.ScopesTest do
  use ExUnit.Case, async: true

  alias Holter.Identity.Scopes

  describe "all/0" do
    test "advertises read:workspaces" do
      assert "read:workspaces" in Scopes.all()
    end

    test "advertises write:monitors" do
      assert "write:monitors" in Scopes.all()
    end

    test "advertises ping:channels" do
      assert "ping:channels" in Scopes.all()
    end

    test "advertises read:integrations" do
      assert "read:integrations" in Scopes.all()
    end

    test "advertises write:integrations" do
      assert "write:integrations" in Scopes.all()
    end

    test "every scope follows the <verb>:<plural-resource> shape" do
      assert Enum.all?(Scopes.all(), &Regex.match?(~r/^[a-z]+:[a-z][a-z_]+s$/, &1))
    end

    test "no duplicates" do
      assert length(Scopes.all()) == Scopes.all() |> Enum.uniq() |> length()
    end
  end

  describe "valid?/1" do
    test "accepts every advertised scope" do
      assert Enum.all?(Scopes.all(), &Scopes.valid?/1)
    end

    test "rejects an unknown scope" do
      refute Scopes.valid?("read:everything")
    end

    test "rejects an atom (only strings are valid)" do
      refute Scopes.valid?(:read_monitors)
    end

    test "rejects nil" do
      refute Scopes.valid?(nil)
    end
  end

  describe "all_valid?/1" do
    test "is true for an all-valid list" do
      assert Scopes.all_valid?(["read:monitors", "write:monitors"])
    end

    test "is false when any element is unknown" do
      refute Scopes.all_valid?(["read:monitors", "admin:everything"])
    end

    test "is true for an empty list (no invalid element to find)" do
      assert Scopes.all_valid?([])
    end

    test "is false for a non-list" do
      refute Scopes.all_valid?("read:monitors")
    end
  end
end
