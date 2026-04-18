defmodule Holter.Credo.Check.Readability.NoComments do
  use Credo.Check,
    base_priority: :high,
    category: :readability,
    explanations: [
      check: """
      Code should be self-documenting. Descriptive comments are forbidden.
      Technical documentation using @doc or @moduledoc is allowed.
      Markdown-style headers (starting with ##) are often part of documentation.
      """
    ]

  def run(source_file, params \\ []) do
    if excluded_file?(source_file.filename) do
      []
    else
      find_issues(source_file, params)
    end
  end

  defp excluded_file?(filename) do
    String.contains?(filename, "lib/credo/") or String.contains?(filename, "test/")
  end

  defp find_issues(source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    source_file
    |> Credo.SourceFile.lines()
    |> Enum.flat_map(&collect_issue(&1, issue_meta))
  end

  defp collect_issue({line_no, line}, issue_meta) do
    if descriptive_comment?(line) do
      [format_issue(issue_meta, line_no, line)]
    else
      []
    end
  end

  defp descriptive_comment?(line) do
    line = String.trim(line)

    String.starts_with?(line, "#") and
      not String.starts_with?(line, "##") and
      not String.starts_with?(line, "#!") and
      not String.starts_with?(line, "#[") and
      String.length(line) > 1 and
      not Regex.match?(~r/^#\s*-+$/, line)
  end

  defp format_issue(issue_meta, line_no, line) do
    format_issue(issue_meta,
      message: "Descriptive comments are forbidden. Refactor code to be self-documenting.",
      trigger: line,
      line_no: line_no
    )
  end
end
