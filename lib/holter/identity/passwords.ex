defmodule Holter.Identity.Passwords do
  @moduledoc """
  Coordinator for the password reset flow (forgot password).

  Owns DB writes, the clock, and mailer side effects. Pure work — strength
  validation, hashing, email composition — happens in sibling modules
  (`Holter.Identity.Password`, `Holter.Identity.Emails.*`).

  Anti-enumeration posture: `request_reset/1` always returns `:ok` and
  produces the same shape of response whether the email exists or not.
  Timing is not hardware-constant — that's a documented out-of-scope
  guarantee — but the user-visible response carries no signal.
  """

  alias Holter.Identity.EmailNormalizer
  alias Holter.Identity.Emails.PasswordChanged
  alias Holter.Identity.Emails.PasswordResetRequest
  alias Holter.Identity.Models.Token
  alias Holter.Identity.Models.User
  alias Holter.Identity.Password
  alias Holter.Identity.Tokens
  alias Holter.Mailers.InfoMailer
  alias Holter.Repo

  def request_reset(email) when is_binary(email) do
    normalized = EmailNormalizer.normalize(email)

    case Repo.get_by(User, email: normalized) do
      nil ->
        :ok

      %User{} = user ->
        with {:ok, _token, plaintext} <- Tokens.create_reset_password_token(user) do
          deliver_reset_request(user, plaintext)
        end

        :ok
    end
  end

  def request_reset(_), do: :ok

  def reset_password(plaintext_token, new_password)
      when is_binary(plaintext_token) and is_binary(new_password) do
    with :ok <- validate_password(new_password),
         {:ok, hashed} <- {:ok, Password.hash(new_password, pepper!())},
         {:ok, user} <- run_reset_transaction(plaintext_token, hashed) do
      _ = deliver_change_alert(user)
      {:ok, user}
    end
  end

  def reset_password(_, _), do: {:error, :invalid_or_expired}

  defp validate_password(password) do
    case Password.validate_strength(password) do
      :ok ->
        :ok

      {:error, message} ->
        cs =
          %User{}
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.add_error(:password, message)
          |> Map.put(:action, :update)

        {:error, cs}
    end
  end

  defp run_reset_transaction(plaintext_token, hashed_password) do
    Repo.transaction(fn ->
      with {:ok, %Token{user_id: user_id}} <- Tokens.consume_reset_password_token(plaintext_token),
           %User{} = user <- Repo.get(User, user_id),
           {:ok, updated} <-
             user
             |> Ecto.Changeset.change(hashed_password: hashed_password)
             |> Repo.update(),
           {:ok, _count} <- Tokens.delete_user_sessions(user_id) do
        updated
      else
        {:error, reason} -> Repo.rollback(reason)
        nil -> Repo.rollback(:invalid_or_expired)
      end
    end)
  end

  defp deliver_reset_request(user, plaintext_token) do
    user
    |> PasswordResetRequest.build_reset_email(%{
      url: build_reset_url(plaintext_token),
      from: from_address()
    })
    |> InfoMailer.deliver()
  end

  defp deliver_change_alert(user) do
    user
    |> PasswordChanged.build_alert_email(%{from: from_address()})
    |> InfoMailer.deliver()
  end

  defp build_reset_url(plaintext_token) do
    HolterWeb.Endpoint.url() <> "/identity/reset-password/" <> plaintext_token
  end

  defp from_address do
    Application.fetch_env!(:holter, :info_email)[:from_address]
  end

  defp pepper! do
    case Application.fetch_env!(:holter, :identity)[:pepper] do
      pepper when is_binary(pepper) and pepper != "" ->
        pepper

      _ ->
        raise "Holter.Identity pepper is not configured. Set IDENTITY_PEPPER or :holter, :identity, pepper."
    end
  end
end
