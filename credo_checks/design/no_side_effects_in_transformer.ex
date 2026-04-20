defmodule Holter.Credo.Check.Design.NoSideEffectsInTransformer do
  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Functions named build_*, compute_*, calculate_*, classify_*, determine_*, parse_*,
      format_*, or encode_* are pure transformers: same input always produces same output.

      These names signal no side effects. Move Repo calls, Broadcaster calls, and
      DateTime.utc_now() to the coordinator level and pass the result as a parameter.

      Example violation:
          defp build_day_range(date, monitor) do
            now = DateTime.utc_now()   # <-- side effect
            ...
          end

      Correct pattern:
          def aggregate(monitor_id, date) do
            now = DateTime.utc_now()                     # coordinator: side effect here
            time_range = build_day_range(date, monitor, now)  # transformer: pure
            ...
          end
      """
    ]

  @pure_prefixes ~w(build_ compute_ calculate_ classify_ determine_ parse_ format_ encode_)

  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  defp traverse({def_type, _meta, [name_args, [do: body]]} = ast, issues, issue_meta)
       when def_type in [:def, :defp] do
    name = extract_fn_name(name_args)

    if is_atom(name) and pure_prefix?(to_string(name)) do
      {ast, find_side_effects(body, issue_meta, name) ++ issues}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp extract_fn_name({:when, _, [head | _]}), do: extract_fn_name(head)
  defp extract_fn_name({name, _, _}), do: name
  defp extract_fn_name(_), do: nil

  defp pure_prefix?(name), do: Enum.any?(@pure_prefixes, &String.starts_with?(name, &1))

  defp find_side_effects(body, issue_meta, fn_name) do
    {_ast, issues} =
      Macro.prewalk(body, [], fn
        {{:., meta, [{:__aliases__, _, aliases}, fun_name]}, _, _} = node, acc ->
          case detect_violation(List.last(aliases), fun_name) do
            nil -> {node, acc}
            label -> {node, [make_issue(issue_meta, fn_name, label, meta[:line]) | acc]}
          end

        node, acc ->
          {node, acc}
      end)

    issues
  end

  defp detect_violation(:Repo, _), do: "Repo (database access)"
  defp detect_violation(:Broadcaster, _), do: "Broadcaster (PubSub side effect)"
  defp detect_violation(:DateTime, :utc_now), do: "DateTime.utc_now() (non-deterministic)"
  defp detect_violation(_, _), do: nil

  defp make_issue(issue_meta, fn_name, label, line_no) do
    format_issue(issue_meta,
      message:
        "Pure transformer '#{fn_name}' contains side effect: #{label}. Move to coordinator.",
      trigger: to_string(fn_name),
      line_no: line_no
    )
  end
end
