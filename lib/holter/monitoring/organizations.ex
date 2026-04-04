defmodule Holter.Monitoring.Organizations do
  @moduledoc false

  alias Holter.Monitoring.Organization
  alias Holter.Repo

  def create_organization(attrs) do
    %Organization{}
    |> Organization.changeset(attrs)
    |> Repo.insert()
  end

  def get_organization_by_slug(slug) do
    case Repo.get_by(Organization, slug: slug) do
      nil -> {:error, :not_found}
      org -> {:ok, org}
    end
  end

  def get_organization!(id), do: Repo.get!(Organization, id)

  def get_organization_by_slug!(slug) do
    Repo.get_by!(Organization, slug: slug)
  end

  def update_organization(%Organization{} = organization, attrs) do
    organization
    |> Organization.changeset(attrs)
    |> Repo.update()
  end
end
