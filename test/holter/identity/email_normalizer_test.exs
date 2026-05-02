defmodule Holter.Identity.EmailNormalizerTest do
  use ExUnit.Case, async: true

  alias Holter.Identity.EmailNormalizer

  describe "normalize/1" do
    test "lowercases mixed-case input" do
      assert EmailNormalizer.normalize("Foo@Bar.COM") == "foo@bar.com"
    end

    test "trims surrounding whitespace" do
      assert EmailNormalizer.normalize("  user@holter.test\n") == "user@holter.test"
    end

    test "preserves '+' aliases (not stripped)" do
      assert EmailNormalizer.normalize("alice+work@holter.test") == "alice+work@holter.test"
    end

    test "is idempotent: normalizing twice yields the same result" do
      input = "  Mixed@Case.IO  "

      assert EmailNormalizer.normalize(input) ==
               input |> EmailNormalizer.normalize() |> EmailNormalizer.normalize()
    end

    test "passes non-binary values through unchanged" do
      assert EmailNormalizer.normalize(nil) == nil
    end
  end
end
