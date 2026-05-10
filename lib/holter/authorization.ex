defmodule Holter.Authorization do
  @moduledoc """
  Application-layer authorization for the Holter domain.

  Every public coordinator function that touches `Repo` should call
  `authorize/3` (or `can?/3`) before any side effect. Decisions are
  encoded in policy modules under `Holter.Authorization.Policies.*` and
  dispatched here based on the subject module.

  ## Vocabulary

  Actions are generic verbs and apply across resources:

    * `:read` — observe the resource (list, show).
    * `:write` — create or update.
    * `:delete` — remove a single instance.
    * `:admin` — operate on the parent resource itself (settings,
      membership management).
    * `:destroy` — destroy the parent resource.

  Each policy declares which of these it supports; unsupported actions
  return `false` (never raise).

  ## Subjects

  A subject is either a struct (the resource instance) or a
  `{module(), parent_struct()}` tuple expressing the *intent* to act on
  a yet-to-exist instance scoped to a parent. Example:

      authorize(user, :write, %Monitor{} = monitor)
      authorize(user, :write, {Monitor, %Workspace{} = workspace})

  ## Actors

  Three actor shapes are recognised:

    * `%Holter.Identity.Models.User{}` — the canonical actor passed by
      LiveViews and API controllers (`current_user`).
    * `%Holter.Identity.Models.ApiToken{}` — accepted as a fallback path
      (mix tasks, IEx, internal flows). Authorization validates that the
      token's `:user` association is preloaded **and** that the token
      carries the scope returned by `scope_for/2` for the action. The
      hot path is to pass `current_user` from `conn.assigns`; reaching
      for the token actor implies the caller has already preloaded
      `:user`.
    * `:system` — escape hatch for cross-tenant background work
      (`MonitorDispatcher`, scanners, daily aggregator). `:system`
      always passes. Callers using it must be either Oban workers under
      `Holter.Monitoring.Workers.*` or domain engines that explicitly
      re-stamp tenant per workspace.

  ## Defense in depth

  This module is the application-layer gate. Postgres RLS (see
  `Holter.Repo.Tenant`) remains enabled as the last line against
  cross-tenant leaks under the `holter_app` role. The two layers
  enforce independent invariants: RLS isolates *tenancy*; this module
  decides *role-based authorization*.
  """

  alias Holter.Authorization.Policies
  alias Holter.Identity.Models.{ApiToken, User}
  alias Holter.Monitoring.Models.Monitor

  def can?(:system, _action, _subject), do: true

  def can?(%ApiToken{user: %User{} = user, scopes: scopes}, action, subject)
      when is_list(scopes) do
    scope_required = scope_for(action, subject_module(subject))

    if scope_required == nil or scope_required in scopes do
      delegate_can?(user, action, subject)
    else
      false
    end
  end

  def can?(%ApiToken{}, _action, _subject), do: false

  def can?(%User{} = user, action, subject), do: delegate_can?(user, action, subject)

  def can?(_actor, _action, _subject), do: false

  def authorize(actor, action, subject) do
    if can?(actor, action, subject), do: :ok, else: {:error, :forbidden}
  end

  def scope_for(action, subject_module) do
    case policy_for_module(subject_module) do
      Policies.Monitor -> Policies.Monitor.scope_for(action)
      nil -> nil
    end
  end

  defp delegate_can?(user, action, subject) do
    case policy_for(subject) do
      Policies.Monitor -> Policies.Monitor.can?(user, action, subject)
      nil -> false
    end
  end

  defp policy_for(%mod{}), do: policy_for_module(mod)
  defp policy_for({mod, _parent}), do: policy_for_module(mod)
  defp policy_for(_), do: nil

  defp subject_module(%mod{}), do: mod
  defp subject_module({mod, _parent}), do: mod
  defp subject_module(_), do: nil

  defp policy_for_module(Monitor), do: Policies.Monitor
  defp policy_for_module(_), do: nil
end
