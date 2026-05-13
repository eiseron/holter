defmodule Holter.System.FeatureFlags do
  @moduledoc """
  Coordinator for feature flags, backed by FunWithFlags. Every mutation
  emits an audit log entry inside a Repo.transaction.
  """

  alias Holter.Identity.Models.User
  alias Holter.Repo
  alias Holter.System.AuditLogs
  alias Holter.System.Models.Admin

  def list_flags do
    {:ok, flags} = FunWithFlags.all_flags()
    Enum.sort_by(flags, & &1.name)
  end

  def get_flag!(name) when is_atom(name) do
    case FunWithFlags.get_flag(name) do
      %FunWithFlags.Flag{} = flag -> flag
      nil -> raise "Flag #{name} not found"
    end
  end

  def get_flag!(name) when is_binary(name), do: get_flag!(String.to_existing_atom(name))

  def enabled?(name, subject) when is_atom(name) do
    FunWithFlags.enabled?(name, for: subject)
  end

  def enabled?(name, subject) when is_binary(name) do
    FunWithFlags.enabled?(String.to_existing_atom(name), for: subject)
  rescue
    ArgumentError -> false
  end

  def create_flag(attrs, %Admin{} = actor_admin) do
    actor_user = Repo.get!(User, actor_admin.user_id)
    name_str = attrs[:name] || attrs["name"]
    now = DateTime.utc_now()

    with :ok <- validate_flag_name(name_str) do
      name = String.to_atom(name_str)
      Repo.transaction(fn -> commit_create(name, actor_user, now) end)
    end
  end

  def set_enabled(%FunWithFlags.Flag{name: name}, enabled, %Admin{} = actor_admin) do
    actor_user = Repo.get!(User, actor_admin.user_id)
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      result =
        if enabled,
          do: FunWithFlags.enable(name),
          else: FunWithFlags.disable(name)

      case result do
        {:ok, _} ->
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

          get_flag!(name)

        {:error, reason} ->
          Repo.rollback(reason)
      end
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

  defp commit_create(name, actor_user, now) do
    case FunWithFlags.disable(name) do
      {:ok, _} ->
        AuditLogs.log!(
          %{
            actor_user: actor_user,
            actor_type: "admin",
            resource: "FeatureFlag:#{name}",
            action: "create_feature_flag",
            diff: %{"name" => to_string(name)}
          },
          now
        )

        get_flag!(name)

      {:error, reason} ->
        Repo.rollback(reason)
    end
  end

  defp validate_flag_name(name_str) when is_binary(name_str) do
    if Regex.match?(~r/^[a-z][a-z0-9_]*$/, name_str) do
      :ok
    else
      {:error, :invalid_name}
    end
  end
end
