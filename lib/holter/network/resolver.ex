defmodule Holter.Network.Resolver do
  @moduledoc """
  Behaviour for resolving a hostname to its IP addresses.

  Provides an indirection over `:inet.getaddrs/2` so tests can stub
  resolution without hitting real DNS, and so dispatch-time SSRF guards
  (`Holter.Network.Guard.validate_destination/1`) have a single
  testable seam.
  """

  @callback getaddrs(host :: charlist(), family :: :inet | :inet6) ::
              {:ok, [:inet.ip_address()]} | {:error, term()}

  defmodule Erlang do
    @moduledoc false
    @behaviour Holter.Network.Resolver

    @impl true
    def getaddrs(host, family), do: :inet.getaddrs(host, family)
  end
end
