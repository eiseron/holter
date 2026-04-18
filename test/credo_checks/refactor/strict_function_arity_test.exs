defmodule Holter.Credo.Check.Refactor.StrictFunctionArityTest do
  use ExUnit.Case, async: true

  Code.require_file("../../../credo_checks/refactor/strict_function_arity.ex", __DIR__)

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  alias Credo.SourceFile
  alias Holter.Credo.Check.Refactor.StrictFunctionArity

  test "it allows functions with up to 3 parameters" do
    source_file =
      """
      defmodule Test do
        def fun1(a), do: a
        def fun2(a, b), do: a + b
        def fun3(a, b, c), do: a + b + c
      end
      """
      |> SourceFile.parse("test.ex")

    issues = StrictFunctionArity.run(source_file)

    assert Enum.empty?(issues)
  end

  test "it reports functions with more than 3 parameters" do
    source_file =
      """
      defmodule Test do
        def fun4(a, b, c, d), do: a + b + c + d
      end
      """
      |> SourceFile.parse("test.ex")

    issues = StrictFunctionArity.run(source_file)

    assert length(issues) == 1
  end

  test "it reports the correct error message for functions with more than 3 parameters" do
    source_file =
      """
      defmodule Test do
        def fun4(a, b, c, d), do: a + b + c + d
      end
      """
      |> SourceFile.parse("test.ex")

    [issue | _] = StrictFunctionArity.run(source_file)

    assert issue.message =~ "arity is 4, max is 3"
  end

  test "it allows framework exceptions regardless of arity" do
    source_file =
      """
      defmodule Test do
        def on_mount(:default, params, session, socket), do: :ok
        def handle_event(event, measurements, metadata, config), do: :ok
      end
      """
      |> SourceFile.parse("test.ex")

    issues = StrictFunctionArity.run(source_file)

    assert Enum.empty?(issues)
  end

  test "it reports private functions with too many parameters" do
    source_file =
      """
      defmodule Test do
        defp private_fun(a, b, c, d), do: :ok
      end
      """
      |> SourceFile.parse("test.ex")

    issues = StrictFunctionArity.run(source_file)

    assert length(issues) == 1
  end

  test "it reports macros with too many parameters" do
    source_file =
      """
      defmodule Test do
        defmacro my_macro(a, b, c, d), do: :ok
      end
      """
      |> SourceFile.parse("test.ex")

    issues = StrictFunctionArity.run(source_file)

    assert length(issues) == 1
  end

  test "it handles functions with guards" do
    source_file =
      """
      defmodule Test do
        def guarded(a, b, c, d) when is_integer(a), do: :ok
      end
      """
      |> SourceFile.parse("test.ex")

    issues = StrictFunctionArity.run(source_file)

    assert length(issues) == 1
  end

  test "it respects custom max_arity param" do
    source_file =
      """
      defmodule Test do
        def fun4(a, b, c, d), do: :ok
      end
      """
      |> SourceFile.parse("test.ex")

    issues = StrictFunctionArity.run(source_file, max_arity: 4)

    assert Enum.empty?(issues)
  end
end
