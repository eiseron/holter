defmodule HolterWeb.ApiTenancy do
  @moduledoc """
  API-side alias of `HolterWeb.ControllerTenancy`. Kept as a named entry
  point so API controllers read as `use HolterWeb.ApiTenancy`; the
  mechanism (overriding `action/2` to wrap the body in the workspace
  tenant context) lives in `HolterWeb.ControllerTenancy`.
  """

  defmacro __using__(opts) do
    quote do
      use HolterWeb.ControllerTenancy, unquote(opts)
    end
  end
end
