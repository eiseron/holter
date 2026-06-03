defmodule Holter.GoogleAdsApiFixtures do
  @moduledoc false

  def success_response, do: %{status: 200, body: %{"results" => []}}

  def rate_limit_response, do: %{status: 429, body: %{"error" => %{"code" => 429}}}

  def unauthorized_response, do: %{status: 401, body: %{"error" => %{"code" => 401}}}
end
