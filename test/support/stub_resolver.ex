defmodule Holter.Test.StubResolver do
  @moduledoc """
  Test-only `Holter.Network.Resolver` implementation.

  Returns deterministic answers so existing monitoring/delivery tests
  that use synthetic hostnames (`test.local`, `*.example.com`, ...)
  don't depend on real DNS. Individual tests that need to assert on
  resolution behavior should use `Mox.expect/3` against
  `Holter.Network.ResolverMock` to override this stub.

  Mapping:
    * `localhost` → `{127, 0, 0, 1}` (matches the real OS resolution)
    * everything else → `{1, 2, 3, 4}` (a public-looking address)
  """
  @behaviour Holter.Network.Resolver

  @impl true
  def getaddrs(~c"localhost", :inet), do: {:ok, [{127, 0, 0, 1}]}
  def getaddrs(_host, :inet), do: {:ok, [{1, 2, 3, 4}]}
  def getaddrs(_host, _family), do: {:error, :nxdomain}
end
