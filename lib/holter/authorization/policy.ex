defmodule Holter.Authorization.Policy do
  @moduledoc """
  Behaviour for resource-specific authorization policies.

  Each policy module owns the rules for a single subject module
  (`Monitor`, `Workspace`, etc.) and is responsible for two questions:

    * `can?/3` — given a `%User{}` actor, an action, and a subject, return
      a boolean. Implementations may inspect both instance subjects
      (`%Monitor{}`) and intent tuples (`{Monitor, %Workspace{}}`).
    * `scope_for/1` — given an action, return the API token scope that a
      `%Holter.Identity.Models.ApiToken{}` actor must carry to perform it (e.g.
      `"read:monitors"`), or `nil` if the action is not surfaced through
      the API.

  `Holter.Authorization` dispatches to one of these by inspecting the
  subject. The behaviour intentionally takes only `%User{}` actors —
  `:system` is short-circuited by the dispatcher and `%ApiToken{}` is
  unwrapped to its user (after validating the carried scope).
  """

  alias Holter.Identity.Models.User

  @callback can?(User.t(), atom(), struct() | {module(), struct()}) :: boolean()
  @callback scope_for(atom()) :: String.t() | nil
end
