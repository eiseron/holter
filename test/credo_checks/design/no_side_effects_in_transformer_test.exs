defmodule Holter.Credo.Check.Design.NoSideEffectsInTransformerTest do
  use ExUnit.Case, async: true

  Code.require_file(
    "../../../credo_checks/design/no_side_effects_in_transformer.ex",
    __DIR__
  )

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  alias Credo.SourceFile
  alias Holter.Credo.Check.Design.NoSideEffectsInTransformer

  test "passes when transformer function has no side effects" do
    source_file =
      """
      defmodule M do
        defp build_result(a, b), do: %{value: a + b}
      end
      """
      |> SourceFile.parse("test.ex")

    assert NoSideEffectsInTransformer.run(source_file) == []
  end

  test "flags Repo call inside build_ function" do
    source_file =
      """
      defmodule M do
        defp build_something(id) do
          Repo.get(MySchema, id)
        end
      end
      """
      |> SourceFile.parse("test.ex")

    issues = NoSideEffectsInTransformer.run(source_file)

    assert length(issues) == 1
  end

  test "flags DateTime.utc_now inside compute_ function" do
    source_file =
      """
      defmodule M do
        defp compute_range(date) do
          now = DateTime.utc_now()
          {date, now}
        end
      end
      """
      |> SourceFile.parse("test.ex")

    issues = NoSideEffectsInTransformer.run(source_file)

    assert length(issues) == 1
  end

  test "flags Broadcaster call inside calculate_ function" do
    source_file =
      """
      defmodule M do
        defp calculate_total(items) do
          result = Enum.sum(items)
          Broadcaster.broadcast(result, :total_calculated, nil)
          result
        end
      end
      """
      |> SourceFile.parse("test.ex")

    issues = NoSideEffectsInTransformer.run(source_file)

    assert length(issues) == 1
  end

  test "does not flag side effects in coordinator-named functions" do
    source_file =
      """
      defmodule M do
        defp aggregate_data(id) do
          Repo.get(MySchema, id)
        end
      end
      """
      |> SourceFile.parse("test.ex")

    assert NoSideEffectsInTransformer.run(source_file) == []
  end

  test "flags all covered prefixes: classify_, determine_, parse_, format_, encode_" do
    source_file =
      """
      defmodule M do
        defp classify_status(x), do: Repo.get(S, x)
        defp determine_ops(x), do: Repo.get(S, x)
        defp parse_input(x), do: Repo.get(S, x)
        defp format_output(x), do: Repo.get(S, x)
        defp encode_payload(x), do: Repo.get(S, x)
      end
      """
      |> SourceFile.parse("test.ex")

    issues = NoSideEffectsInTransformer.run(source_file)

    assert length(issues) == 5
  end

  test "message includes the function name" do
    source_file =
      """
      defmodule M do
        defp build_attrs(x) do
          Repo.all(Query)
        end
      end
      """
      |> SourceFile.parse("test.ex")

    [issue] = NoSideEffectsInTransformer.run(source_file)

    assert issue.message =~ "build_attrs"
  end

  test "message includes the side effect label" do
    source_file =
      """
      defmodule M do
        defp build_attrs(x) do
          Repo.all(Query)
        end
      end
      """
      |> SourceFile.parse("test.ex")

    [issue] = NoSideEffectsInTransformer.run(source_file)

    assert issue.message =~ "Repo"
  end

  test "flags public transformer functions too" do
    source_file =
      """
      defmodule M do
        def build_response(data) do
          Repo.insert(data)
        end
      end
      """
      |> SourceFile.parse("test.ex")

    issues = NoSideEffectsInTransformer.run(source_file)

    assert length(issues) == 1
  end

  test "handles guarded transformer functions" do
    source_file =
      """
      defmodule M do
        defp compute_ratio(a, b) when b > 0 do
          DateTime.utc_now()
          a / b
        end
      end
      """
      |> SourceFile.parse("test.ex")

    issues = NoSideEffectsInTransformer.run(source_file)

    assert length(issues) == 1
  end
end
