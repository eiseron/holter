defmodule Holter.RLSHelpers do
  @moduledoc """
  Shared role-switching helpers for tests that need to exercise RLS
  policies under the `holter_app` role.

  Usable from any test case (DataCase, ConnCase, RLSConnCase).
  """

  @doc """
  `SET LOCAL ROLE holter_app` on the sandbox connection. Must be
  called *before* the production code path being exercised.

  Does NOT pre-stamp `app.current_user_id` or `app.current_workspace_id`
  — production starts every connection unstamped, and we want our
  tests to fail if app code forgets to wrap reads in
  `Holter.Repo.Tenant.with_user!/2` or `with_workspace!/2`.

  Returns `:ok`. The sandbox transaction rolls back at end of test,
  so no manual reset is needed.
  """
  def setup_app_role do
    Holter.Repo.query!("SET LOCAL ROLE holter_app", [])
    Holter.Repo.query!("SELECT set_config('app.current_workspace_id', '', true)", [])
    Holter.Repo.query!("SELECT set_config('app.current_user_id', '', true)", [])
    :ok
  end
end
