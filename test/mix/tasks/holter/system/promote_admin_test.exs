defmodule Mix.Tasks.Holter.System.PromoteAdminTest do
  use Holter.DataCase, async: false

  import ExUnit.CaptureIO

  alias Holter.System

  @task Mix.Tasks.Holter.System.PromoteAdmin

  defp run_task(args) do
    capture_io(fn -> @task.run(args) end)
  end

  defp run_failing_task(args) do
    capture_io(:stderr, fn ->
      catch_exit(@task.run(args))
    end)
  end

  describe "without --actor and zero existing admins" do
    test "bootstraps the first admin" do
      user = user_fixture()
      run_task([user.email])
      assert System.admin?(user)
    end

    test "prints an [OK] line referencing the target email" do
      user = user_fixture()
      output = run_task([user.email])
      assert output =~ "[OK] Bootstrapped first admin: " <> user.email
    end
  end

  describe "without --actor when admins already exist" do
    test "writes an error to stderr" do
      _existing = admin_fixture()
      target = user_fixture()
      output = run_failing_task([target.email])
      assert output =~ "[ERR] Admins already exist"
    end

    test "leaves the target without an admin row" do
      _existing = admin_fixture()
      target = user_fixture()
      run_failing_task([target.email])
      refute System.admin?(target)
    end
  end

  describe "with --actor" do
    test "promotes the target attributed to the actor" do
      actor_admin = admin_fixture()
      target = user_fixture()
      run_task([target.email, "--actor", actor_admin.user.email])
      assert System.admin?(target)
    end

    test "errors when the actor email does not exist" do
      target = user_fixture()
      output = run_failing_task([target.email, "--actor", "ghost@h.test"])
      assert output =~ "Actor email ghost@h.test not found"
    end

    test "errors when the actor is not an active admin" do
      non_admin = user_fixture()
      target = user_fixture()
      output = run_failing_task([target.email, "--actor", non_admin.email])
      assert output =~ "is not an active admin"
    end
  end

  describe "idempotency" do
    test "is a no-op when target is already admin" do
      admin = admin_fixture()
      output = run_task([admin.user.email])
      assert output =~ "[NOOP]"
    end
  end

  describe "argument errors" do
    test "writes a usage line when no email is supplied" do
      output = run_failing_task([])
      assert output =~ "Usage:"
    end

    test "writes an error when the target email does not exist" do
      output = run_failing_task(["ghost@h.test"])
      assert output =~ "No user with email"
    end
  end
end
