defmodule Holter.Integrations.Models.IntegrationRule do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Holter.Integrations.Models.Integration
  alias Holter.Monitoring.Models.Monitor

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @event_types ~w(incident_opened incident_resolved monitor_paused monitor_resumed)
  @actions ~w(pause_campaign resume_campaign pause_ad_set resume_ad_set)
  @target_types ~w(campaign ad_set)

  @action_to_target_type %{
    "pause_campaign" => "campaign",
    "resume_campaign" => "campaign",
    "pause_ad_set" => "ad_set",
    "resume_ad_set" => "ad_set"
  }

  @target_id_max 255
  @target_label_max 255

  schema "integration_rules" do
    field :event_type, :string
    field :action, :string
    field :target_type, :string
    field :target_id, :string
    field :target_label, :string

    belongs_to :integration, Integration
    belongs_to :monitor, Monitor

    timestamps(type: :utc_datetime)
  end

  def event_types, do: @event_types
  def actions, do: @actions
  def target_types, do: @target_types
  def target_type_for_action(action), do: Map.get(@action_to_target_type, action)

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [
      :integration_id,
      :monitor_id,
      :event_type,
      :action,
      :target_id,
      :target_label
    ])
    |> validate_required([:integration_id, :monitor_id, :event_type, :action, :target_id])
    |> validate_inclusion(:event_type, @event_types)
    |> validate_inclusion(:action, @actions)
    |> derive_target_type()
    |> validate_inclusion(:target_type, @target_types)
    |> validate_length(:target_id, min: 1, max: @target_id_max)
    |> validate_length(:target_label, max: @target_label_max)
    |> assoc_constraint(:integration)
    |> assoc_constraint(:monitor)
    |> unique_constraint(
      [:integration_id, :monitor_id, :event_type, :action, :target_id],
      name: :integration_rules_uniqueness_index,
      message: "rule already exists for this monitor, event, and target"
    )
  end

  defp derive_target_type(changeset) do
    case get_field(changeset, :action) do
      nil -> changeset
      action -> put_change(changeset, :target_type, Map.get(@action_to_target_type, action))
    end
  end
end
