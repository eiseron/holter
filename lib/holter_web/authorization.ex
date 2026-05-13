defmodule HolterWeb.Authorization do
  @moduledoc """
  Boundary helper that resolves the right `Holter.<Context>.Policies.<Resource>`
  module from the subject and delegates to `Bodyguard.permit/4`. Controllers
  and LiveViews call `authorize(user, :delete, monitor)` without aliasing or
  knowing about per-resource policy modules.

  ## Usage

  `HolterWeb.controller/0` and the LiveView macros already
  `import HolterWeb.Authorization`, so call sites just write:

      with :ok <- authorize(actor, :delete, monitor),
           {:ok, _} <- Monitoring.delete_monitor(monitor) do
        ...
      end

  ## `:create` and other parent-rooted actions

  When the subject is the parent of a not-yet-existing resource (typically
  on `:create`), there is no struct to infer from. Pass an explicit
  `{ResourceModule, parent}` tuple:

      authorize(actor, :create, {Monitor, workspace})
      authorize(actor, :create, {ApiToken, workspace})

  The policy receives `parent` as its subject — same shape as a direct
  `Bodyguard.permit/4` call on the corresponding policy.
  """

  alias Holter.Delivery.Policies, as: D
  alias Holter.Identity.Policies, as: I
  alias Holter.Monitoring.Policies, as: M
  alias Holter.System.Policies, as: S

  @doc """
  Authorizes `user` to perform `action` on `subject`. Returns `:ok` or
  `{:error, :unauthorized}`.
  """
  @spec authorize(any, atom, any) :: :ok | {:error, any}
  def authorize(user, action, subject) when is_struct(subject) do
    Bodyguard.permit(policy_for(subject), action, user, subject)
  end

  def authorize(user, action, {resource_module, parent}) do
    Bodyguard.permit(policy_for_module(resource_module), action, user, parent)
  end

  defp policy_for(%Holter.Monitoring.Models.Monitor{}), do: M.Monitor
  defp policy_for(%Holter.Monitoring.Models.Workspace{}), do: M.Workspace
  defp policy_for(%Holter.Monitoring.Models.Incident{}), do: M.Incident
  defp policy_for(%Holter.Monitoring.Models.MonitorLog{}), do: M.MonitorLog
  defp policy_for(%Holter.Monitoring.Models.DailyMetric{}), do: M.DailyMetric
  defp policy_for(%Holter.Delivery.Models.EmailChannel{}), do: D.EmailChannel
  defp policy_for(%Holter.Delivery.Models.WebhookChannel{}), do: D.WebhookChannel
  defp policy_for(%Holter.Identity.Models.ApiToken{}), do: I.ApiToken
  defp policy_for(%Holter.Identity.Models.User{}), do: S.User
  defp policy_for(%Holter.System.Models.Admin{}), do: S.Admin
  defp policy_for(%FunWithFlags.Flag{}), do: S.FeatureFlag

  defp policy_for_module(Holter.Monitoring.Models.Monitor), do: M.Monitor
  defp policy_for_module(Holter.Monitoring.Models.Workspace), do: M.Workspace
  defp policy_for_module(Holter.Delivery.Models.EmailChannel), do: D.EmailChannel
  defp policy_for_module(Holter.Delivery.Models.WebhookChannel), do: D.WebhookChannel
  defp policy_for_module(Holter.Identity.Models.ApiToken), do: I.ApiToken
  defp policy_for_module(Holter.Identity.Models.User), do: S.User
  defp policy_for_module(Holter.System.Models.Admin), do: S.Admin
  defp policy_for_module(FunWithFlags.Flag), do: S.FeatureFlag
end
