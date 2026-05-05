defmodule Holter.Credo.Check.Design.RLSPolicyRequired do
  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Migrations that introduce a `:workspace_id` column (either on a new
      table or added to an existing one) must also enable Row-Level
      Security and create the matching tenant-isolation policy in the
      same migration.

      The default Postgres role used by the running app (`holter_app`)
      cannot bypass RLS, so a workspace-scoped table without a policy
      would be invisible to the application even when correctly
      populated. Defense in depth: enforcing this at migration time
      stops a forgotten ENABLE / CREATE POLICY from shipping silently.

      Required co-occurrence in the same migration file:

        * `execute("ALTER TABLE <name> ENABLE ROW LEVEL SECURITY")`
        * `execute("CREATE POLICY <pol> ON <name> ...")`

      Indirect-scoped tables (no `workspace_id` column, anchored via a
      foreign key) are out of scope here — they are covered by manual
      review until a richer check exists.

      Migrations whose timestamp is older than `@grandfather_cutoff`
      (the date the RLS infrastructure landed) are skipped: the policy
      cannot be retrofitted into a historical migration without
      breaking replay. New tables added on or after that date must
      comply.
      """
    ]

  @grandfather_cutoff "20260504230358"

  def run(source_file, params \\ []) do
    if migration_file?(source_file) and post_cutoff?(source_file) do
      issue_meta = IssueMeta.for(source_file, params)
      ast = SourceFile.ast(source_file)

      {tables_with_workspace_id, enabled_rls, policy_tables} = collect(ast)

      tables_with_workspace_id
      |> Enum.flat_map(fn {table, line_no} ->
        missing_for(table, line_no, enabled_rls, policy_tables, issue_meta)
      end)
    else
      []
    end
  end

  defp migration_file?(%SourceFile{filename: path}) do
    String.contains?(path, "priv/repo/migrations/") and String.ends_with?(path, ".exs")
  end

  defp post_cutoff?(%SourceFile{filename: path}) do
    case Regex.run(~r"priv/repo/migrations/(\d{14})_", path) do
      [_, version] -> version >= @grandfather_cutoff
      _ -> false
    end
  end

  defp collect(ast) do
    Macro.prewalk(ast, {%{}, MapSet.new(), MapSet.new()}, fn node, acc ->
      acc =
        case node do
          {:create, _, [{:table, _, table_args}, [do: body]]} ->
            register_workspace_id_columns(body, extract_table_name(table_args), node, acc)

          {:alter, _, [{:table, _, table_args}, [do: body]]} ->
            register_workspace_id_columns(body, extract_table_name(table_args), node, acc)

          {:execute, _, [arg]} when is_binary(arg) ->
            scan_execute_string(arg, acc)

          _ ->
            acc
        end

      {node, acc}
    end)
    |> elem(1)
  end

  defp extract_table_name([name | _]) when is_atom(name), do: name
  defp extract_table_name(_), do: nil

  defp register_workspace_id_columns(_body, nil, _node, acc), do: acc

  defp register_workspace_id_columns(body, table_name, node, {tables, enabled, policies}) do
    line_no = node |> elem(1) |> Keyword.get(:line, 0)

    if has_workspace_id_add?(body) do
      {Map.put(tables, table_name, line_no), enabled, policies}
    else
      {tables, enabled, policies}
    end
  end

  defp has_workspace_id_add?(body) do
    {_ast, found?} =
      Macro.prewalk(body, false, fn
        {:add, _, [:workspace_id | _]} = node, _acc -> {node, true}
        node, acc -> {node, acc}
      end)

    found?
  end

  defp scan_execute_string(sql, {tables, enabled, policies}) do
    upper = String.upcase(sql)

    enabled =
      case Regex.run(~r/ALTER\s+TABLE\s+(\w+)\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY/i, sql) do
        [_, name] -> MapSet.put(enabled, String.to_atom(name))
        _ -> enabled
      end

    policies =
      case Regex.run(~r/CREATE\s+POLICY\s+\w+\s+ON\s+(\w+)/i, sql) do
        [_, name] -> MapSet.put(policies, String.to_atom(name))
        _ -> policies
      end

    _ = upper
    {tables, enabled, policies}
  end

  defp missing_for(table, line_no, enabled, policies, issue_meta) do
    missing =
      []
      |> maybe_add_missing(:enable, MapSet.member?(enabled, table))
      |> maybe_add_missing(:policy, MapSet.member?(policies, table))

    case missing do
      [] -> []
      labels -> [build_issue(issue_meta, table, line_no, labels)]
    end
  end

  defp maybe_add_missing(list, _label, true), do: list
  defp maybe_add_missing(list, label, false), do: [label | list]

  defp build_issue(issue_meta, table, line_no, missing_labels) do
    descriptions =
      Enum.map(missing_labels, fn
        :enable -> "ENABLE ROW LEVEL SECURITY"
        :policy -> "CREATE POLICY ... ON #{table}"
      end)

    format_issue(issue_meta,
      message:
        "Workspace-scoped table `#{table}` is missing in this migration: " <>
          Enum.join(descriptions, " and ") <> ".",
      trigger: to_string(table),
      line_no: line_no
    )
  end
end
