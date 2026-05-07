defmodule HolterWeb.StaticCachePolicy do
  @moduledoc false

  @spec etag_cache_control(boolean()) :: String.t()
  def etag_cache_control(true), do: "no-cache"
  def etag_cache_control(false), do: "public, max-age=86400"

  @spec vsn_cache_control(boolean()) :: String.t()
  def vsn_cache_control(true), do: "no-cache"
  def vsn_cache_control(false), do: "public, max-age=31536000, immutable"
end
