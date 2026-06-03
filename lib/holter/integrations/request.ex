defmodule Holter.Integrations.Request do
  @moduledoc """
  Provider-agnostic outbound request produced by an action's `encode/2`.

  The `ActionRunner` executes it; providers never perform IO themselves.
  """

  @enforce_keys [:url, :body]
  defstruct method: :post, url: nil, headers: [], body: %{}

  @type t :: %__MODULE__{
          method: atom(),
          url: String.t(),
          headers: list(),
          body: map()
        }
end
