defmodule Holter.System.FeatureFlagsTest do
  use Holter.DataCase, async: false

  alias Holter.System
  alias Holter.System.FeatureFlags
  alias Holter.System.Models.AuditLog

  setup do
    on_exit(fn ->
      {:ok, flags} = FunWithFlags.all_flags()
      Enum.each(flags, fn f -> FunWithFlags.clear(f.name) end)
    end)
  end

  describe "known_flags/0" do
    test "returns a list" do
      assert is_list(FeatureFlags.known_flags())
    end

    test "every entry is an atom" do
      assert Enum.all?(FeatureFlags.known_flags(), &is_atom/1)
    end

    test "includes :maintenance_mode" do
      assert :maintenance_mode in FeatureFlags.known_flags()
    end
  end

  describe "list_flags/0" do
    test "returns all known flags" do
      flags = FeatureFlags.list_flags()
      names = Enum.map(flags, & &1.name)
      assert :maintenance_mode in names
    end

    test "returns flags in alphabetical order" do
      flags = FeatureFlags.list_flags()
      names = Enum.map(flags, & &1.name)
      assert names == Enum.sort(names)
    end

    test "returns uninitialized flags as disabled" do
      flags = FeatureFlags.list_flags()
      flag = Enum.find(flags, &(&1.name == :maintenance_mode))
      refute FeatureFlags.boolean_enabled?(flag)
    end
  end

  describe "get_flag!/1" do
    test "returns a known flag by atom" do
      flag = FeatureFlags.get_flag!(:maintenance_mode)
      assert flag.name == :maintenance_mode
    end

    test "returns a known flag by string" do
      flag = FeatureFlags.get_flag!("maintenance_mode")
      assert flag.name == :maintenance_mode
    end

    test "raises on unknown flag" do
      assert_raise ArgumentError, fn ->
        FeatureFlags.get_flag!("not_a_known_flag")
      end
    end
  end

  describe "toggle/3" do
    test "enables a flag" do
      admin = admin_fixture()
      flag = FeatureFlags.get_flag!(:maintenance_mode)
      {:ok, updated} = FeatureFlags.toggle(flag, true, admin)
      assert FeatureFlags.boolean_enabled?(updated)
    end

    test "disables a flag" do
      admin = admin_fixture()
      FunWithFlags.enable(:maintenance_mode)
      flag = FeatureFlags.get_flag!(:maintenance_mode)
      {:ok, updated} = FeatureFlags.toggle(flag, false, admin)
      refute FeatureFlags.boolean_enabled?(updated)
    end

    test "emits a toggle audit log entry" do
      admin = admin_fixture()
      flag = FeatureFlags.get_flag!(:maintenance_mode)
      {:ok, _} = FeatureFlags.toggle(flag, true, admin)
      audits = Repo.all(AuditLog)
      assert Enum.any?(audits, &(&1.action == "toggle_feature_flag"))
    end
  end

  describe "enabled?/2" do
    test "returns false for a disabled known flag" do
      user = user_fixture()
      refute FeatureFlags.enabled?(:maintenance_mode, user)
    end

    test "returns true for an enabled known flag" do
      FunWithFlags.enable(:maintenance_mode)
      user = user_fixture()
      assert FeatureFlags.enabled?(:maintenance_mode, user)
    end

    test "returns false for an unknown flag name string" do
      user = user_fixture()
      refute FeatureFlags.enabled?("nonexistent_flag_abc", user)
    end
  end

  describe "gate_summary/1" do
    test "returns :global when only boolean gate exists" do
      flag = %FunWithFlags.Flag{name: :maintenance_mode, gates: []}
      assert {:global, nil} = FeatureFlags.gate_summary(flag)
    end

    test "returns :percentage when percentage_of_actors gate exists" do
      gate = %FunWithFlags.Gate{type: :percentage_of_actors, for: 0.5, enabled: true}
      flag = %FunWithFlags.Flag{name: :maintenance_mode, gates: [gate]}
      assert {:percentage, 50} = FeatureFlags.gate_summary(flag)
    end

    test "returns :list with actor count when actor gates exist" do
      gate1 = %FunWithFlags.Gate{type: :actor, for: "user:1", enabled: true}
      gate2 = %FunWithFlags.Gate{type: :actor, for: "user:2", enabled: true}
      flag = %FunWithFlags.Flag{name: :maintenance_mode, gates: [gate1, gate2]}
      assert {:list, 2} = FeatureFlags.gate_summary(flag)
    end
  end

  describe "get_flag!/1 with existing non-flag atom" do
    test "raises on atom that exists but is not a known flag" do
      assert_raise ArgumentError, fn ->
        FeatureFlags.get_flag!("true")
      end
    end
  end

  describe "System context delegates" do
    test "known_feature_flags/0 delegates to FeatureFlags" do
      assert System.known_feature_flags() == FeatureFlags.known_flags()
    end

    test "get_feature_flag!/1 delegates to FeatureFlags" do
      assert System.get_feature_flag!(:maintenance_mode).name == :maintenance_mode
    end

    test "feature_enabled?/2 delegates to FeatureFlags" do
      user = user_fixture()
      refute System.feature_enabled?(:maintenance_mode, user)
    end
  end

  describe "boolean_enabled?/1" do
    test "returns true when boolean gate is enabled" do
      FunWithFlags.enable(:maintenance_mode)
      flag = FeatureFlags.get_flag!(:maintenance_mode)
      assert FeatureFlags.boolean_enabled?(flag)
    end

    test "returns false when boolean gate is disabled" do
      flag = FeatureFlags.get_flag!(:maintenance_mode)
      refute FeatureFlags.boolean_enabled?(flag)
    end
  end
end
