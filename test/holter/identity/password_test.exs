defmodule Holter.Identity.PasswordTest do
  use ExUnit.Case, async: true

  alias Holter.Identity.Password

  @pepper "test-pepper"
  @other_pepper "different-pepper"
  @valid "Holter-Foundation-1!"

  describe "hash/2 and verify/3" do
    test "verify accepts the same plaintext that was hashed with the same pepper" do
      hashed = Password.hash(@valid, @pepper)

      assert Password.verify(@valid, hashed, @pepper)
    end

    test "verify rejects an incorrect plaintext" do
      hashed = Password.hash(@valid, @pepper)

      refute Password.verify("Wrong-Password-1!", hashed, @pepper)
    end

    test "verify rejects the correct plaintext under a rotated pepper" do
      hashed = Password.hash(@valid, @pepper)

      refute Password.verify(@valid, hashed, @other_pepper)
    end

    test "the hash never equals the plaintext" do
      refute Password.hash(@valid, @pepper) == @valid
    end

    test "hashing the same plaintext twice produces distinct outputs (random salt)" do
      refute Password.hash(@valid, @pepper) == Password.hash(@valid, @pepper)
    end

    test "verify/3 with a non-binary hash performs a constant-time dummy check and returns false" do
      refute Password.verify(@valid, nil, @pepper)
    end
  end

  describe "validate_strength/1" do
    test "accepts a sufficiently strong password" do
      assert Password.validate_strength("Holter-Foundation-1!") == :ok
    end

    test "rejects passwords below the minimum length" do
      assert {:error, "must be at least 12 characters"} =
               Password.validate_strength("Short-1A")
    end

    test "rejects passwords with no lowercase letter" do
      assert {:error, "must contain a lowercase letter"} =
               Password.validate_strength("ALLCAPS-12345!")
    end

    test "rejects passwords with no uppercase letter" do
      assert {:error, "must contain an uppercase letter"} =
               Password.validate_strength("alllower-12345!")
    end

    test "rejects passwords with no digit" do
      assert {:error, "must contain a digit"} =
               Password.validate_strength("NoDigitsHere!")
    end

    test "rejects non-string inputs" do
      assert {:error, "must be a string"} = Password.validate_strength(nil)
    end
  end
end
