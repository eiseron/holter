defmodule Holter.Identity.Users do
  @moduledoc """
  Coordinator for the user lifecycle: registration (with default
  workspace + owner membership + verification token) and credential
  lookup. Mirrors the `Holter.Monitoring.Monitors` shape — pure
  helpers live in sibling modules; this module owns DB writes,
  the clock and configuration reads.
  """

  alias Eiseron.I18n.Locale
  alias Eiseron.Identity.EmailNormalizer
  alias Eiseron.Identity.Password
  alias Holter.Identity.Emails.RegistrationVerification
  alias Holter.Identity.Memberships
  alias Holter.Identity.Models.Token
  alias Holter.Identity.Models.User
  alias Holter.Identity.Tokens
  alias Holter.Mailers.InfoMailer
  alias Holter.Monitoring
  alias Holter.Repo

  def register_user(attrs) do
    raw_password = Map.get(attrs, :password) || Map.get(attrs, "password")

    with :ok <- validate_password(raw_password),
         {:ok, hashed_password} <- {:ok, Password.hash(raw_password, pepper!())},
         user_attrs <- build_user_attrs(attrs, hashed_password),
         {:ok, user, workspace, raw_token} <- run_registration_transaction(user_attrs) do
      _ = deliver_verification(user, raw_token)
      {:ok, user, workspace, raw_token}
    end
  end

  def get_user!(id), do: Repo.get!(User, id)

  def update_user_preferences(%User{} = user, attrs) do
    user
    |> User.preferences_changeset(attrs)
    |> Repo.update()
  end

  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    pepper = pepper!()

    case Repo.get_by(User, email: EmailNormalizer.normalize(email)) do
      nil ->
        Password.verify(password, nil, pepper)
        nil

      %User{} = user ->
        if Password.verify(password, user.hashed_password, pepper), do: user, else: nil
    end
  end

  def get_user_by_email_and_password(_, _), do: nil

  def verify_email(plaintext_token) when is_binary(plaintext_token) do
    case Tokens.consume_verify_email_token(plaintext_token) do
      {:ok, %Token{user_id: user_id}} ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        user_id
        |> get_user!()
        |> User.email_verification_changeset(now)
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  def verify_email(_), do: {:error, :invalid_or_expired}

  defp validate_password(password) do
    case Password.validate_strength(password) do
      :ok ->
        :ok

      {:error, reason} ->
        {msg, opts} = password_strength_message(reason)

        cs =
          %User{}
          |> Ecto.Changeset.change()
          |> Map.put(:params, %{"password" => password})
          |> Ecto.Changeset.add_error(:password, msg, opts)
          |> Map.put(:action, :insert)

        {:error, cs}
    end
  end

  defp password_strength_message(:too_short),
    do: {"must be at least %{min} characters", [min: Password.min_length()]}

  defp password_strength_message(:missing_lowercase),
    do: {"must contain a lowercase letter", []}

  defp password_strength_message(:missing_uppercase),
    do: {"must contain an uppercase letter", []}

  defp password_strength_message(:missing_digit),
    do: {"must contain a digit", []}

  defp password_strength_message(:not_a_string),
    do: {"must be a string", []}

  defp build_user_attrs(attrs, hashed_password) do
    attrs
    |> stringify_keys()
    |> Map.put("hashed_password", hashed_password)
    |> Map.delete("password")
  end

  defp stringify_keys(attrs) do
    Map.new(attrs, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp run_registration_transaction(user_attrs) do
    Repo.transaction(fn ->
      with {:ok, user} <- insert_user(user_attrs),
           {:ok, workspace} <- create_default_workspace(user),
           {:ok, _membership} <- Memberships.create_default_membership(user, workspace),
           {:ok, _token, raw_token} <- Tokens.create_verify_email_token(user) do
        %{user: user, workspace: workspace, raw_verify_token: raw_token}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, %{user: user, workspace: workspace, raw_verify_token: raw_token}} ->
        {:ok, user, workspace, raw_token}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp insert_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  defp create_default_workspace(%User{id: user_id, email: email}) do
    Monitoring.create_workspace(%{
      name: build_default_workspace_name(email, user_id),
      default_locale: Locale.default()
    })
  end

  defp build_default_workspace_name(email, user_id) do
    local_part = email |> String.split("@") |> List.first()
    short_id = user_id |> String.replace("-", "") |> String.slice(0, 8)
    "#{local_part}-#{short_id}"
  end

  defp pepper! do
    case Application.fetch_env!(:holter, :identity)[:pepper] do
      pepper when is_binary(pepper) and pepper != "" ->
        pepper

      _ ->
        raise "Holter.Identity pepper is not configured. Set IDENTITY_PEPPER or :holter, :identity, pepper."
    end
  end

  defp deliver_verification(user, raw_token) do
    user
    |> RegistrationVerification.build_verification_email(%{
      url: build_verification_url(raw_token),
      from: from_address()
    })
    |> InfoMailer.deliver()
  end

  defp build_verification_url(raw_token) do
    HolterWeb.Endpoint.url() <> "/identity/verify-email/" <> raw_token
  end

  defp from_address do
    Application.fetch_env!(:holter, :info_email)[:from_address]
  end
end
