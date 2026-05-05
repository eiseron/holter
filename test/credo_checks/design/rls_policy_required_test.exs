defmodule Holter.Credo.Check.Design.RLSPolicyRequiredTest do
  use ExUnit.Case, async: true

  Code.require_file(
    "../../../credo_checks/design/rls_policy_required.ex",
    __DIR__
  )

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  alias Credo.SourceFile
  alias Holter.Credo.Check.Design.RLSPolicyRequired

  @migration_path "priv/repo/migrations/20260601000000_test_migration.exs"

  test "passes when create table has workspace_id and the migration also enables RLS + creates policy" do
    source = """
    defmodule M do
      use Ecto.Migration

      def change do
        create table(:foos, primary_key: false) do
          add :id, :binary_id, primary_key: true
          add :workspace_id, references(:workspaces, type: :binary_id), null: false
          add :name, :string
        end

        execute("ALTER TABLE foos ENABLE ROW LEVEL SECURITY")
        execute("CREATE POLICY tenant_isolation ON foos USING (true) WITH CHECK (true)")
      end
    end
    """

    assert RLSPolicyRequired.run(parse(source)) == []
  end

  test "flags create table with workspace_id when ENABLE RLS is missing" do
    source = """
    defmodule M do
      use Ecto.Migration

      def change do
        create table(:foos, primary_key: false) do
          add :id, :binary_id, primary_key: true
          add :workspace_id, references(:workspaces, type: :binary_id), null: false
        end

        execute("CREATE POLICY tenant_isolation ON foos USING (true) WITH CHECK (true)")
      end
    end
    """

    [issue] = RLSPolicyRequired.run(parse(source))

    assert issue.message =~ "ENABLE ROW LEVEL SECURITY"
  end

  test "flags create table with workspace_id when CREATE POLICY is missing" do
    source = """
    defmodule M do
      use Ecto.Migration

      def change do
        create table(:foos, primary_key: false) do
          add :workspace_id, references(:workspaces, type: :binary_id), null: false
        end

        execute("ALTER TABLE foos ENABLE ROW LEVEL SECURITY")
      end
    end
    """

    [issue] = RLSPolicyRequired.run(parse(source))

    assert issue.message =~ "CREATE POLICY"
  end

  test "flags alter table that adds workspace_id without RLS in same migration" do
    source = """
    defmodule M do
      use Ecto.Migration

      def change do
        alter table(:foos) do
          add :workspace_id, references(:workspaces, type: :binary_id), null: false
        end
      end
    end
    """

    issues = RLSPolicyRequired.run(parse(source))

    assert length(issues) == 1
  end

  test "ignores tables without workspace_id" do
    source = """
    defmodule M do
      use Ecto.Migration

      def change do
        create table(:foos) do
          add :name, :string
        end
      end
    end
    """

    assert RLSPolicyRequired.run(parse(source)) == []
  end

  test "ignores files outside priv/repo/migrations/" do
    source = """
    defmodule M do
      def change do
        create table(:foos) do
          add :workspace_id, references(:workspaces, type: :binary_id)
        end
      end
    end
    """

    source_file = SourceFile.parse(source, "lib/some_module.ex")

    assert RLSPolicyRequired.run(source_file) == []
  end

  test "skips grandfathered migrations created before the cutoff" do
    source = """
    defmodule M do
      use Ecto.Migration

      def change do
        create table(:foos) do
          add :workspace_id, references(:workspaces, type: :binary_id)
        end
      end
    end
    """

    grandfathered =
      SourceFile.parse(source, "priv/repo/migrations/20260101000000_legacy.exs")

    assert RLSPolicyRequired.run(grandfathered) == []
  end

  test "issue message names the offending table" do
    source = """
    defmodule M do
      use Ecto.Migration

      def change do
        create table(:offending_table) do
          add :workspace_id, references(:workspaces, type: :binary_id)
        end
      end
    end
    """

    [issue] = RLSPolicyRequired.run(parse(source))

    assert issue.message =~ "offending_table"
  end

  test "policy declared for the table satisfies the policy requirement" do
    source = """
    defmodule M do
      use Ecto.Migration

      def change do
        create table(:foos) do
          add :workspace_id, references(:workspaces, type: :binary_id)
        end

        execute("ALTER TABLE foos ENABLE ROW LEVEL SECURITY")
        execute(\"\"\"
          CREATE POLICY tenant_isolation ON foos
            USING (workspace_id = current_setting('app.current_workspace_id')::uuid)
            WITH CHECK (workspace_id = current_setting('app.current_workspace_id')::uuid)
        \"\"\")
      end
    end
    """

    assert RLSPolicyRequired.run(parse(source)) == []
  end

  defp parse(source), do: SourceFile.parse(source, @migration_path)
end
