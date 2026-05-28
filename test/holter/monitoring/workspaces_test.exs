defmodule Holter.Monitoring.WorkspacesTest do
  use Holter.DataCase, async: true

  alias Eiseron.I18n.Locale
  alias Holter.Monitoring

  describe "create_workspace/1 — atomicity" do
    test "returns {:ok, %Workspace{}} on success so transactional setup composes" do
      assert {:ok, %Holter.Monitoring.Models.Workspace{slug: "acme-co"}} =
               Monitoring.create_workspace(%{name: "Acme", slug: "acme-co"})
    end

    test "rolls back returning the changeset (not :rollback) when validation fails" do
      {:error, %Ecto.Changeset{} = changeset} = Monitoring.create_workspace(%{name: nil})

      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "create_workspace/1 — default_locale" do
    test "uses the configured Gettext default when caller omits :default_locale" do
      {:ok, workspace} = Monitoring.create_workspace(%{name: "Acme"})

      assert workspace.default_locale == Locale.default()
    end

    test "stores an explicit supported locale" do
      {:ok, workspace} = Monitoring.create_workspace(%{name: "Acme", default_locale: "en"})

      assert workspace.default_locale == "en"
    end

    test "rejects an unsupported locale" do
      {:error, changeset} =
        Monitoring.create_workspace(%{name: "Acme", default_locale: "fr_FR"})

      assert "is not a supported locale" in errors_on(changeset).default_locale
    end
  end

  describe "update_workspace/2 — default_locale" do
    test "persists a supported locale to the workspace row" do
      workspace = workspace_fixture()

      {:ok, _} = Monitoring.update_workspace(workspace, %{default_locale: "en"})

      assert Monitoring.get_workspace!(workspace.id).default_locale == "en"
    end

    test "rejects an unsupported locale with a translatable error" do
      workspace = workspace_fixture()

      {:error, changeset} =
        Monitoring.update_workspace(workspace, %{default_locale: "klingon"})

      assert "is not a supported locale" in errors_on(changeset).default_locale
    end

    test "leaves the row unchanged when an unsupported locale is supplied" do
      workspace = workspace_fixture()
      original = workspace.default_locale

      {:error, _} = Monitoring.update_workspace(workspace, %{default_locale: "klingon"})

      assert Monitoring.get_workspace!(workspace.id).default_locale == original
    end

    test "coerces a nil default_locale back to the configured app default" do
      workspace = workspace_fixture()

      {:ok, updated} = Monitoring.update_workspace(workspace, %{default_locale: nil})

      assert updated.default_locale == Locale.default()
    end
  end
end
