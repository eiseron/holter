defmodule Holter.Credo.Check.Testing.OneAssertPerTest do
  use Credo.Check,
    base_priority: :high,
    category: :consistency,
    explanations: [
      check: """
      Each test should ideally contain exactly one assertion.
      This makes tests more readable and easier to debug.
      """
    ]

  def run(source_file, params \\ []) do
    if String.ends_with?(source_file.filename, "_test.exs") do
      issue_meta = IssueMeta.for(source_file, params)
      Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp traverse({:test, _, [_name, [do: block]]} = ast, issues, issue_meta) do
    assert_count = count_asserts(block)

    if assert_count > 1 do
      {ast, [format_issue(issue_meta, ast, assert_count) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp count_asserts(block) do
    {_ast, count} =
      Macro.prewalk(block, 0, fn
        {:assert, _, _} = ast, acc -> {ast, acc + 1}
        {:assert_receive, _, _} = ast, acc -> {ast, acc + 1}
        {:assert_received, _, _} = ast, acc -> {ast, acc + 1}
        {:assert_enqueued, _, _} = ast, acc -> {ast, acc + 1}
        ast, acc -> {ast, acc}
      end)

    count
  end

  defp format_issue(issue_meta, {:test, meta, [name | _]}, count) do
    format_issue(issue_meta,
      message: "Test '#{name}' has #{count} assertions. Aim for exactly one assert per test.",
      line_no: meta[:line]
    )
  end
end
