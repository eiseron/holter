defmodule Holter.GoogleAdsApiFixtures do
  @moduledoc """
  Documented Google Ads API response shapes for mock-based tests.

  Shapes follow the published `campaigns:mutate` contract and the Google
  API error envelope. Real captures are reconciled into these fixtures in
  the live-verification phase of #115.
  """

  def success_response do
    %{
      status: 200,
      body: %{
        "results" => [
          %{"resourceName" => "customers/1234567890/campaigns/123"}
        ]
      }
    }
  end

  def rate_limit_response do
    %{
      status: 429,
      body: %{
        "error" => %{
          "code" => 429,
          "status" => "RESOURCE_EXHAUSTED",
          "message" => "Quota exceeded."
        }
      }
    }
  end

  def unauthorized_response do
    %{
      status: 401,
      body: %{
        "error" => %{
          "code" => 401,
          "status" => "UNAUTHENTICATED",
          "message" => "Request had invalid authentication credentials."
        }
      }
    }
  end

  def forbidden_response do
    %{
      status: 403,
      body: %{
        "error" => %{
          "code" => 403,
          "status" => "PERMISSION_DENIED",
          "message" => "The caller does not have permission."
        }
      }
    }
  end
end
