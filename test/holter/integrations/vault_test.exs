defmodule Holter.Integrations.VaultTest do
  use ExUnit.Case, async: true

  alias Holter.Integrations.Vault

  describe "encrypt/decrypt round-trip" do
    test "ciphertext differs from plaintext" do
      plaintext = "super_secret_token_value"
      {:ok, ciphertext} = Vault.encrypt(plaintext)
      assert ciphertext != plaintext
    end

    test "decrypts back to the original plaintext" do
      plaintext = "super_secret_token_value"
      {:ok, ciphertext} = Vault.encrypt(plaintext)
      assert {:ok, ^plaintext} = Vault.decrypt(ciphertext)
    end

    test "produces different ciphertexts for the same plaintext (AES-GCM nonce)" do
      plaintext = "same_value"
      {:ok, ct1} = Vault.encrypt(plaintext)
      {:ok, ct2} = Vault.encrypt(plaintext)

      assert ct1 != ct2
    end
  end
end
