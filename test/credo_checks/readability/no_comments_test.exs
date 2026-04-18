defmodule Holter.Credo.Check.Readability.NoCommentsTest do
  use ExUnit.Case, async: true

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  alias Credo.SourceFile
  alias Holter.Credo.Check.Readability.NoComments

  @c "#"

  test "it reports descriptive comments" do
    source_file =
      ("defmodule Test do\n  " <> @c <> " This is a descriptive comment\n  def run, do: :ok\nend")
      |> SourceFile.parse("test.ex")

    issues = NoComments.run(source_file)

    assert length(issues) == 1
  end

  test "it provides correct message for descriptive comments" do
    source_file =
      ("defmodule Test do\n  " <> @c <> " This is a descriptive comment\n  def run, do: :ok\nend")
      |> SourceFile.parse("test.ex")

    [issue | _] = NoComments.run(source_file)

    assert issue.message =~ "Descriptive comments are forbidden"
  end

  test "it allows @doc and @moduledoc" do
    source_file =
      """
      defmodule Test do
        @moduledoc "Module doc"
        @doc "Function doc"
        def run, do: :ok
      end
      """
      |> SourceFile.parse("test.ex")

    issues = NoComments.run(source_file)

    assert Enum.empty?(issues)
  end

  test "it allows markdown headers" do
    source_file =
      """
      defmodule Test do
        ## Implementation
        def run, do: :ok
      end
      """
      |> SourceFile.parse("test.ex")

    issues = NoComments.run(source_file)

    assert Enum.empty?(issues)
  end

  test "it reports credo control comments" do
    source_file =
      ("defmodule Test do\n  " <> @c <> " credo:disable-for-next-line\n  def run, do: :ok\nend")
      |> SourceFile.parse("test.ex")

    issues = NoComments.run(source_file)

    assert length(issues) == 1
  end

  test "it allows divider lines" do
    source_file =
      ("defmodule Test do\n  " <> @c <> " ---\n  def run, do: :ok\nend")
      |> SourceFile.parse("test.ex")

    issues = NoComments.run(source_file)

    assert Enum.empty?(issues)
  end
end
