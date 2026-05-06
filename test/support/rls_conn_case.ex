defmodule HolterWeb.RLSConnCase do
  @moduledoc """
  ConnCase variant that runs LiveView / HTTP tests under the
  `holter_app` Postgres role with Row-Level Security actually enforced.

  The default test sandbox connects as `postgres` (a superuser, which
  bypasses every RLS policy regardless of `FORCE ROW LEVEL SECURITY`).
  That makes ordinary tests blind to the class of bugs where the app
  forgets to stamp the tenant before a read — the policy never fires
  in test, the read succeeds, the suite stays green even though
  production (running as `<slug>_app`, no BYPASSRLS) returns no rows
  and the LiveView mount blows up with `Ecto.NoResultsError`.

  This module bridges that gap. Tests `use HolterWeb.RLSConnCase`
  and call `setup_app_role/0` early in the test (or in `setup`) to
  `SET LOCAL ROLE holter_app` on the sandbox connection. The role
  lasts for the test transaction; sandbox rolls back at the end.

  **Crucially the helper does NOT pre-stamp `app.current_user_id`.**
  Pre-stamping would mask the bug class this case is meant to catch:
  if every query under the test sees `current_user_id` set, then
  unwrapped lookups in mount/handle_event silently work, just like
  they do under the superuser sandbox today. By leaving the variable
  unset, we force application code to stamp it through
  `Holter.Repo.Tenant.with_user!/2` or `with_workspace!/2` exactly as
  it must in production — and to read tenant-aware assigns instead of
  refetching by id without context. This is what production actually
  faces: every connection from the pool starts with no session
  variables; only the wrapper at the call site sets them, and only
  for the wrapper's lifetime.

  The Sandbox's `:shared` mode shares the connection with the
  LiveView/Conn process, so queries triggered by `live(...)` or
  `get(...)` inherit the role and see the policies the way production
  does.

  Tests using this case must be `async: false` (sandbox shared mode is
  incompatible with async).
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use HolterWeb.ConnCase, async: false

      import Holter.RLSHelpers, only: [setup_app_role: 0]
    end
  end
end
