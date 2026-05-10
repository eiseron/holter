defmodule HolterWeb.Api.Security do
  @moduledoc """
  Bearer token auth declaration shared by every OpenAPI spec module.

  Public API endpoints under `/api/v1` require an `Authorization: Bearer
  <token>` header carrying a Holter API token (workspace-scoped, see
  `Holter.Identity.ApiToken`). This module exports the scheme entry to
  drop into `components.securitySchemes` and the global requirement to
  apply it to every operation by default.
  """

  alias OpenApiSpex.SecurityScheme

  def schemes do
    %{
      "bearerAuth" => %SecurityScheme{
        type: "http",
        scheme: "bearer",
        bearerFormat: "Holter API token (hk_...)",
        description: """
        Workspace-scoped API token issued via `/identity/settings/api-tokens`.
        Send as `Authorization: Bearer hk_...`. Each token carries one or
        more scopes (e.g. `read:monitors`, `write:monitors`); endpoints
        document the scope they require in their 403 response body.
        """
      }
    }
  end

  def requirement, do: [%{"bearerAuth" => []}]
end
