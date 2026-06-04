defmodule Holter.Integrations.Models.IntegrationAuditLogTest do
  use ExUnit.Case, async: true

  alias Holter.Integrations.Models.IntegrationAuditLog

  defp valid_attrs do
    %{
      actor_type: "user",
      actor_id: Ecto.UUID.generate(),
      workspace_id: Ecto.UUID.generate(),
      resource: "integration:slack",
      action: "integrations.connected",
      occurred_at: DateTime.utc_now()
    }
  end

  defp changeset(attrs), do: IntegrationAuditLog.insert_changeset(%IntegrationAuditLog{}, attrs)

  describe "insert_changeset/2" do
    test "is valid for a user actor with an actor_id" do
      assert changeset(valid_attrs()).valid?
    end

    test "is valid for a system actor without an actor_id" do
      attrs = %{valid_attrs() | actor_type: "system", actor_id: nil}

      assert changeset(attrs).valid?
    end

    test "requires actor_id when actor_type is user" do
      attrs = %{valid_attrs() | actor_id: nil}

      refute changeset(attrs).valid?
    end

    test "rejects an actor_id when actor_type is system" do
      attrs = %{valid_attrs() | actor_type: "system"}

      refute changeset(attrs).valid?
    end

    test "requires workspace_id" do
      attrs = Map.delete(valid_attrs(), :workspace_id)

      refute changeset(attrs).valid?
    end

    test "rejects an unknown actor_type" do
      attrs = %{valid_attrs() | actor_type: "admin"}

      refute changeset(attrs).valid?
    end
  end
end
