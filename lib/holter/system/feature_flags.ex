defmodule Holter.System.FeatureFlags do
  @moduledoc """
  Coordinator for feature flags, backed by FunWithFlags. Flag names are
  compile-time atoms declared in @known_flags — adding a flag requires a
  code change (PR review, deploy). Toggling on/off is runtime via admin UI
  (no deploy, no downtime). Every mutation emits an audit log entry.
  """

  alias Holter.Identity.Models.User
  alias Holter.Repo
  alias Holter.System.AuditLogs
  alias Holter.System.Models.Admin

  @known_flags [
    :maintenance_mode
  ]

  def known_flags, do: @known_flags

  def list_flags do
    Enum.map(@known_flags, &get_or_init_flag/1)
    |> Enum.sort_by(& &1.name)
  end

  def get_flag!(name) when is_atom(name) and name in @known_flags do
    get_or_init_flag(name)
  end

  def get_flag!(name) when is_binary(name) do
    get_flag!(to_known_atom!(name))
  end

  def enabled?(name, subject) when is_atom(name) and name in @known_flags do
    FunWithFlags.enabled?(name, for: subject)
  end

  def enabled?(name, subject) when is_binary(name) do
    enabled?(to_known_atom!(name), subject)
  rescue
    ArgumentError -> false
  end

  def toggle(%FunWithFlags.Flag{name: name}, enabled, %Admin{} = actor_admin)
      when name in @known_flags do
    actor_user = Repo.get!(User, actor_admin.user_id)
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      {:ok, _} =
        if enabled,
          do: FunWithFlags.enable(name),
          else: FunWithFlags.disable(name)

      AuditLogs.log!(
        %{
          actor_user: actor_user,
          actor_type: "admin",
          resource: "FeatureFlag:#{name}",
          action: "toggle_feature_flag",
          diff: %{"from" => !enabled, "to" => enabled}
        },
        now
      )

      get_or_init_flag(name)
    end)
  end

  def boolean_enabled?(%FunWithFlags.Flag{gates: gates}) do
    case Enum.find(gates, &(&1.type == :boolean)) do
      %{enabled: enabled} -> enabled
      nil -> false
    end
  end

  def gate_summary(%FunWithFlags.Flag{gates: gates}) do
    cond do
      Enum.any?(gates, &(&1.type == :percentage_of_actors)) ->
        gate = Enum.find(gates, &(&1.type == :percentage_of_actors))
        pct = trunc(gate.for * 100)
        {:percentage, pct}

      Enum.any?(gates, &(&1.type == :actor)) ->
        count = Enum.count(gates, &(&1.type == :actor))
        {:list, count}

      true ->
        {:global, nil}
    end
  end

  defp get_or_init_flag(name) when is_atom(name) do
    case FunWithFlags.get_flag(name) do
      %FunWithFlags.Flag{} = flag -> flag
      nil -> %FunWithFlags.Flag{name: name, gates: []}
    end
  end

  defp to_known_atom!(name_str) when is_binary(name_str) do
    flag_name = String.to_existing_atom(name_str)

    if flag_name in @known_flags do
      flag_name
    else
      raise ArgumentError, "unknown feature flag: #{name_str}"
    end
  end
end
