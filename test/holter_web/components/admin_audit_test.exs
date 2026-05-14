defmodule HolterWeb.Components.AdminAuditTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias HolterWeb.Components.AdminAudit

  describe "audit_resource/1" do
    test "renders a link to /admin/users/:id for User:<uuid> values" do
      uuid = Ecto.UUID.generate()
      html = render_component(&AdminAudit.audit_resource/1, value: "User:" <> uuid)
      assert html =~ ~s|href="/admin/users/#{uuid}"|
    end

    test "renders a link to /admin/workspaces/:id for Workspace:<uuid> values" do
      uuid = Ecto.UUID.generate()
      html = render_component(&AdminAudit.audit_resource/1, value: "Workspace:" <> uuid)
      assert html =~ ~s|href="/admin/workspaces/#{uuid}"|
    end

    test "renders unknown resource strings as a plain monospace span" do
      html = render_component(&AdminAudit.audit_resource/1, value: "Unknown:xyz")
      refute html =~ "<a"
      assert html =~ "Unknown:xyz"
    end
  end

  describe "audit_actor/1" do
    test "renders 'system' for system actors" do
      html = render_component(&AdminAudit.audit_actor/1, actor_id: nil, actor_type: "system")
      assert html =~ "system"
      refute html =~ "<a"
    end

    test "renders a link to /admin/users/:id for admin actors" do
      uuid = Ecto.UUID.generate()
      html = render_component(&AdminAudit.audit_actor/1, actor_id: uuid, actor_type: "admin")
      assert html =~ ~s|href="/admin/users/#{uuid}"|
    end

    test "renders a muted dash when actor_id is missing on a non-system actor" do
      html = render_component(&AdminAudit.audit_actor/1, actor_id: nil, actor_type: "admin")
      assert html =~ "—"
      refute html =~ "<a"
    end
  end
end
