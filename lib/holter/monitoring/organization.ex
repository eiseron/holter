defmodule Holter.Monitoring.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "organizations" do
    field :name, :string
    field :slug, :string

    has_many :monitors, Holter.Monitoring.Monitor

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name])
    |> maybe_generate_slug()
    |> validate_required([:slug])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_format(:slug, ~r/^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$/,
      message: "must be 3-63 lowercase alphanumeric characters or hyphens"
    )
    |> validate_slug_immutability()
    |> unique_constraint(:slug)
  end

  defp maybe_generate_slug(changeset) do
    case {get_field(changeset, :slug), get_change(changeset, :name)} do
      {nil, name} when is_binary(name) ->
        put_change(changeset, :slug, slugify(name))

      _ ->
        changeset
    end
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/[\s]+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
    |> String.slice(0, 63)
  end

  defp validate_slug_immutability(changeset) do
    if changeset.data.id && get_change(changeset, :slug) do
      add_error(changeset, :slug, "cannot be changed after creation")
    else
      changeset
    end
  end
end
