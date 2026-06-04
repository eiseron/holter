defmodule Holter.MetaAdsApiFixtures do
  @moduledoc """
  Documented Meta Graph API response shapes for mock-based tests.

  Shapes follow the Graph API error envelope (`error.type`, `error.code`,
  `error.fbtrace_id`). Graph throttling can also surface as HTTP 400 with an
  error subcode; the rate-limit fixture uses 429 to match the status-based
  classification. Real captures are reconciled into these fixtures in the
  live-verification phase of #115.
  """

  def success_response, do: %{status: 200, body: %{"success" => true}}

  def rate_limit_response do
    %{
      status: 429,
      body: %{
        "error" => %{
          "message" => "User request limit reached",
          "type" => "OAuthException",
          "code" => 17,
          "fbtrace_id" => "A1bcDefGhiJ"
        }
      }
    }
  end

  def unauthorized_response do
    %{
      status: 401,
      body: %{
        "error" => %{
          "message" => "Invalid OAuth access token.",
          "type" => "OAuthException",
          "code" => 190,
          "fbtrace_id" => "A1bcDefGhiJ"
        }
      }
    }
  end

  def forbidden_response do
    %{
      status: 403,
      body: %{
        "error" => %{
          "message" => "Permissions error",
          "type" => "OAuthException",
          "code" => 200,
          "fbtrace_id" => "A1bcDefGhiJ"
        }
      }
    }
  end
end
