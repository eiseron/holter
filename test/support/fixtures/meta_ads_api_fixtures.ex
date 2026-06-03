defmodule Holter.MetaAdsApiFixtures do
  @moduledoc false

  def success_response, do: %{status: 200, body: %{"success" => true}}

  def rate_limit_response, do: %{status: 429, body: %{"error" => %{"code" => 4}}}

  def unauthorized_response, do: %{status: 401, body: %{"error" => %{"code" => 190}}}
end
