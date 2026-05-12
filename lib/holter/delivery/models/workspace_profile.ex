defmodule Holter.Delivery.Models.WorkspaceProfile do
  use Ecto.Schema
  use Gettext, backend: HolterWeb.Gettext

  import Ecto.Changeset
  import Ecto.Query

  alias Holter.Delivery.Models.{EmailChannel, WebhookChannel}
  alias Holter.Monitoring.Models.Workspace

  @primary_key false
  @foreign_key_type :binary_id

  schema "delivery_workspace_profiles" do
    belongs_to :workspace, Workspace, primary_key: true

    field :max_channels, :integer, default: 2

    timestamps(type: :utc_datetime)
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:workspace_id, :max_channels])
    |> validate_required([:workspace_id, :max_channels])
    |> validate_number(:max_channels, greater_than_or_equal_to: 1)
    |> foreign_key_constraint(:workspace_id)
  end

  @doc """
  Defense-in-depth guard for channel inserts. Called from
  `prepare_changes/2` on `WebhookChannel.changeset/2` and
  `EmailChannel.changeset/2`, so it runs inside the same transaction
  Ecto opens around the insert.

  Acquires `SELECT ... FOR UPDATE` on the profile row to serialize
  concurrent creates against the same workspace, then counts the
  combined `webhook_channels + email_channels` and rejects with
  `code: :channel_quota_reached` when at the cap.
  """
  def guard_channel_insert!(%Ecto.Changeset{} = changeset) do
    workspace_id = get_field(changeset, :workspace_id)

    profile =
      from(p in __MODULE__,
        where: p.workspace_id == ^workspace_id,
        lock: "FOR UPDATE"
      )
      |> changeset.repo.one!()

    webhook_count =
      from(w in WebhookChannel, where: w.workspace_id == ^workspace_id)
      |> changeset.repo.aggregate(:count, :id)

    email_count =
      from(e in EmailChannel, where: e.workspace_id == ^workspace_id)
      |> changeset.repo.aggregate(:count, :id)

    if webhook_count + email_count >= profile.max_channels do
      add_error(
        changeset,
        :workspace_id,
        gettext("Channel limit reached for this workspace (max: %{max})",
          max: profile.max_channels
        ),
        code: :channel_quota_reached
      )
    else
      changeset
    end
  end
end
