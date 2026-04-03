defmodule Holter.Monitoring.TenantLimits do
  @moduledoc false

  alias Holter.Monitoring.TenantLimit
  alias Holter.Repo

  def get_retention_days(nil), do: 3

  def get_retention_days(user_id) do
    case Repo.get(TenantLimit, user_id) do
      %TenantLimit{retention_days: days} -> days
      nil -> 3
    end
  end
end
