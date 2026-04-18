defmodule Holter.Credo.Check.Refactor.StrictFunctionArity do
  use Credo.Check,
    base_priority: :high,
    category: :refactor,
    param_defaults: [max_arity: 3],
    explanations: [
      check: """
      Functions should take as few parameters as possible to improve readability and maintainability.
      Eiseron standards limit functions to a maximum of 3 parameters.
      If more data is needed, group parameters into a Map or Struct.
      """
    ]

  @framework_exceptions [
    {:on_mount, 4},
    {:handle_event, 4}
  ]

  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    max_arity = Params.get(params, :max_arity, 3)

    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta, max_arity))
  end

  defp traverse({def_type, meta, [name_args | _]} = ast, issues, issue_meta, max_arity)
       when def_type in [:def, :defp, :defmacro, :defmacrop] do
    {name, args} = decompose_name_args(name_args)
    arity = length(args)

    if arity > max_arity and not exception?(name, arity) do
      issue = format_issue(issue_meta, name, arity, max_arity, meta[:line])
      {ast, [issue | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta, _max_arity) do
    {ast, issues}
  end

  defp decompose_name_args({:when, _, [left | _]}), do: decompose_name_args(left)
  defp decompose_name_args({name, _, args}) when is_list(args), do: {name, args}
  defp decompose_name_args({name, _, _}), do: {name, []}

  defp exception?(name, arity) do
    Enum.any?(@framework_exceptions, fn {ex_name, ex_arity} ->
      ex_name == name and ex_arity == arity
    end)
  end

  defp format_issue(issue_meta, name, arity, max_arity, line_no) do
    format_issue(issue_meta,
      message:
        "Function '#{name}' takes too many parameters (arity is #{arity}, max is #{max_arity}).",
      trigger: to_string(name),
      line_no: line_no
    )
  end
end
