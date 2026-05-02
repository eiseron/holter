defmodule Holter.Identity.Password do
  @moduledoc """
  Pure helpers for password hashing and strength validation.

  Argon2ID with a server-side pepper combined
  before hashing so a database leak alone is not enough to mount an offline
  brute-force attack. The Argon2 variant is pinned to `id` (the hybrid that
  resists both side-channel and GPU attacks) via
  `config :argon2_elixir, argon2_type: 2` in `config/config.exs`. Cost
  parameters are turned down in `config/test.exs` so the suite stays fast.
  """

  use Gettext, backend: HolterWeb.Gettext

  @min_length 12
  @strength_rules [:too_short, :missing_lowercase, :missing_uppercase, :missing_digit]

  def min_length, do: @min_length

  def hash(plaintext, pepper) when is_binary(plaintext) and is_binary(pepper) do
    Argon2.hash_pwd_salt(plaintext <> pepper)
  end

  def verify(plaintext, hashed, pepper)
      when is_binary(plaintext) and is_binary(hashed) and is_binary(pepper) do
    Argon2.verify_pass(plaintext <> pepper, hashed)
  end

  def verify(_plaintext, _hashed, _pepper) do
    Argon2.no_user_verify()
    false
  end

  def validate_strength(password) when is_binary(password) do
    Enum.reduce_while(@strength_rules, :ok, fn rule, _acc ->
      if obeys?(rule, password), do: {:cont, :ok}, else: {:halt, {:error, message_for(rule)}}
    end)
  end

  def validate_strength(_), do: {:error, gettext("must be a string")}

  defp obeys?(:too_short, password), do: String.length(password) >= @min_length
  defp obeys?(:missing_lowercase, password), do: String.match?(password, ~r/[a-z]/)
  defp obeys?(:missing_uppercase, password), do: String.match?(password, ~r/[A-Z]/)
  defp obeys?(:missing_digit, password), do: String.match?(password, ~r/[0-9]/)

  defp message_for(:too_short),
    do: gettext("must be at least %{min} characters", min: @min_length)

  defp message_for(:missing_lowercase), do: gettext("must contain a lowercase letter")
  defp message_for(:missing_uppercase), do: gettext("must contain an uppercase letter")
  defp message_for(:missing_digit), do: gettext("must contain a digit")
end
