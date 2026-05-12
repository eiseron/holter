defmodule Holter.Monitoring.Models.Workspace do
  use Ecto.Schema
  use Gettext, backend: HolterWeb.Gettext

  import Ecto.Changeset

  alias Holter.I18n.Locale

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workspaces" do
    field :name, :string
    field :slug, :string
    field :default_locale, :string

    has_many :monitors, Holter.Monitoring.Models.Monitor

    has_one :monitoring_profile, Holter.Monitoring.Models.WorkspaceProfile,
      foreign_key: :workspace_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [:name, :slug, :default_locale])
    |> validate_required([:name])
    |> maybe_generate_slug()
    |> maybe_apply_default_locale()
    |> validate_required([:slug, :default_locale])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_format(:slug, ~r/^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$/,
      message: "must be 3-63 lowercase alphanumeric characters or hyphens"
    )
    |> validate_default_locale()
    |> validate_slug_immutability()
    |> unique_constraint(:slug)
  end

  defp maybe_apply_default_locale(changeset) do
    case get_field(changeset, :default_locale) do
      nil -> put_change(changeset, :default_locale, Locale.default())
      _ -> changeset
    end
  end

  defp validate_default_locale(changeset) do
    validate_change(changeset, :default_locale, fn :default_locale, value ->
      if Locale.valid?(value),
        do: [],
        else: [default_locale: gettext("is not a supported locale")]
    end)
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
      add_error(changeset, :slug, gettext("cannot be changed after creation"))
    else
      changeset
    end
  end
end
