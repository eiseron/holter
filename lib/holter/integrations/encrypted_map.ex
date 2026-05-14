defmodule Holter.Integrations.EncryptedMap do
  @moduledoc false
  use Cloak.Ecto.Map, vault: Holter.Integrations.Vault
end
