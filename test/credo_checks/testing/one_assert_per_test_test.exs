defmodule Holter.Credo.Check.Testing.OneAssertPerTestTest do
  use ExUnit.Case, async: true

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  alias Credo.SourceFile
  alias Holter.Credo.Check.Testing.OneAssertPerTest

  test "it allows tests with one assertion" do
    source_file =
      """
      defmodule MyTest do
        use ExUnit.Case
        test "one" do
          assert 1 == 1
        end
      end
      """
      |> SourceFile.parse("my_test.exs")

    issues = OneAssertPerTest.run(source_file)

    assert Enum.empty?(issues)
  end

  test "it reports tests with more than one assertion" do
    source_file =
      """
      defmodule MyTest do
        use ExUnit.Case
        test "two" do
          assert 1 == 1
          assert 2 == 2
        end
      end
      """
      |> SourceFile.parse("my_test.exs")

    issues = OneAssertPerTest.run(source_file)

    assert length(issues) == 1
  end

  test "reports correct message for multiple assertions" do
    source_file =
      """
      defmodule MyTest do
        use ExUnit.Case
        test "two" do
          assert 1 == 1
          assert 2 == 2
        end
      end
      """
      |> SourceFile.parse("my_test.exs")

    [issue | _] = OneAssertPerTest.run(source_file)

    assert issue.message =~ "has 2 assertions"
  end

  test "it counts assert_receive, assert_received and assert_enqueued" do
    source_file =
      """
      defmodule MyTest do
        use ExUnit.Case
        test "mixed" do
          assert 1 == 1
          assert_receive :hey
          assert_received :hey
          assert_enqueued worker: MyWorker
        end
      end
      """
      |> SourceFile.parse("my_test.exs")

    issues = OneAssertPerTest.run(source_file)

    assert length(issues) == 1
  end

  test "reports correct count for mixed assertions" do
    source_file =
      """
      defmodule MyTest do
        use ExUnit.Case
        test "mixed" do
          assert 1 == 1
          assert_receive :hey
          assert_received :hey
          assert_enqueued worker: MyWorker
        end
      end
      """
      |> SourceFile.parse("my_test.exs")

    [issue | _] = OneAssertPerTest.run(source_file)

    assert issue.message =~ "has 4 assertions"
  end

  test "it ignores files that do not end in _test.exs" do
    source_file =
      """
      defmodule MyModule do
        def test_like_fun do
          test "not a real test" do
            assert 1 == 1
            assert 2 == 2
          end
        end
      end
      """
      |> SourceFile.parse("my_module.ex")

    issues = OneAssertPerTest.run(source_file)

    assert Enum.empty?(issues)
  end
end
