defmodule Holter.Monitoring.Workers.WorkspaceScopedWorkerTest do
  @moduledoc """
  Macro contract tests. Each scenario defines a tiny worker module
  inline (so the macro's `__before_compile__` runs), then exercises
  `perform/1` directly to assert the wrap actually engages.
  """

  use Holter.DataCase, async: false

  alias Holter.Repo.Tenant

  defmodule FakeWorker do
    use Holter.Monitoring.Workers.WorkspaceScopedWorker, queue: :default

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"capture" => key}}) do
      Process.put(key, Tenant.current_workspace_id())
      :ok
    end
  end

  describe "perform/1 wrap" do
    test "returns :ok when workspace_id is present and the user clause succeeds" do
      job = %Oban.Job{args: %{"workspace_id" => Ecto.UUID.generate(), "capture" => :ok_check}}

      assert :ok = FakeWorker.perform(job)
    end

    test "stamps app.current_workspace_id from job args before delegating to the user clause" do
      workspace_id = Ecto.UUID.generate()
      key = :"captured_#{System.unique_integer([:positive])}"

      FakeWorker.perform(%Oban.Job{args: %{"workspace_id" => workspace_id, "capture" => key}})

      assert Process.get(key) == workspace_id
    end

    test "tenant from a prior job does not leak into a later job's perform" do
      first_id = Ecto.UUID.generate()
      second_id = Ecto.UUID.generate()
      first_key = :"captured_#{System.unique_integer([:positive])}"
      second_key = :"captured_#{System.unique_integer([:positive])}"

      FakeWorker.perform(%Oban.Job{
        args: %{"workspace_id" => first_id, "capture" => first_key}
      })

      FakeWorker.perform(%Oban.Job{
        args: %{"workspace_id" => second_id, "capture" => second_key}
      })

      assert Process.get(second_key) == second_id
    end

    test "raises ArgumentError when workspace_id is missing — fails loud rather than silently retrying" do
      job = %Oban.Job{args: %{"capture" => :ignored}}

      assert_raise ArgumentError, ~r/requires "workspace_id"/, fn ->
        FakeWorker.perform(job)
      end
    end

    test "raises ArgumentError when workspace_id is not a string" do
      job = %Oban.Job{args: %{"workspace_id" => 12_345, "capture" => :ignored}}

      assert_raise ArgumentError, ~r/requires "workspace_id"/, fn ->
        FakeWorker.perform(job)
      end
    end
  end

  describe "Oban.Worker delegation" do
    test "FakeWorker.new/1 produces a changeset for the FakeWorker queue" do
      changeset = FakeWorker.new(%{"workspace_id" => Ecto.UUID.generate(), "capture" => :k})

      assert Ecto.Changeset.get_field(changeset, :queue) == "default"
    end

    test "FakeWorker.new/1 produces a changeset that names the FakeWorker module as the worker" do
      changeset = FakeWorker.new(%{"workspace_id" => Ecto.UUID.generate(), "capture" => :k})

      assert Ecto.Changeset.get_field(changeset, :worker) ==
               "Holter.Monitoring.Workers.WorkspaceScopedWorkerTest.FakeWorker"
    end
  end
end
