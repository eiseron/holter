defmodule Holter.Seeds.Identity.ApiTokens do
  @moduledoc false

  alias Holter.Identity.ApiTokens
  alias Holter.Identity.Scopes
  alias Holter.Identity.User
  alias Holter.Monitoring.Workspace

  def create_dev(%User{} = user, %Workspace{} = workspace) do
    {:ok, _token, plaintext} =
      ApiTokens.create_token(user, workspace, %{
        name: "Dev seed token",
        scopes: Scopes.all()
      })

    IO.puts("[seeds] Created dev API token (workspace: #{workspace.slug}): #{plaintext}")
    plaintext
  end
end
