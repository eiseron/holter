defmodule Holter.System.Policies.FeatureFlag do
  @moduledoc """
  Authorization policy for feature flags (FunWithFlags).
  Every action is gated behind an active admin row.
  """

  @behaviour Bodyguard.Policy

  alias Holter.Identity.Models.User
  alias Holter.System.Admins

  @impl true
  def authorize(_action, :system, _subject), do: :ok

  def authorize(action, %User{} = actor, subject)
      when action in [:list, :read, :create, :update] do
    if Admins.admin?(actor) and feature_flag_subject?(subject),
      do: :ok,
      else: {:error, :unauthorized}
  end

  def authorize(_action, _user, _subject), do: {:error, :unauthorized}

  defp feature_flag_subject?(%FunWithFlags.Flag{}), do: true
  defp feature_flag_subject?(FunWithFlags.Flag), do: true
  defp feature_flag_subject?(nil), do: true
  defp feature_flag_subject?(_), do: false
end
