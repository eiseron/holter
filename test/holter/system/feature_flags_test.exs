defmodule Holter.System.FeatureFlagsTest do
  use Holter.DataCase, async: false

  alias Holter.System.FeatureFlags
  alias Holter.System.Models.AuditLog

  setup do
    on_exit(fn ->
      {:ok, flags} = FunWithFlags.all_flags()
      Enum.each(flags, fn f -> FunWithFlags.clear(f.name) end)
    end)
  end

  describe "list_flags/0" do
    test "includes created flags" do
      feature_flag_fixture(%{name: "listed_flag"})
      names = FeatureFlags.list_flags() |> Enum.map(& &1.name)
      assert :listed_flag in names
    end

    test "returns flags in alphabetical order" do
      feature_flag_fixture(%{name: "zz_last"})
      feature_flag_fixture(%{name: "aa_first"})

      names = FeatureFlags.list_flags() |> Enum.map(& &1.name)
      assert names == Enum.sort(names)
    end
  end

  describe "get_flag!/1" do
    test "returns a flag by atom name" do
      feature_flag_fixture(%{name: "my_test_flag"})
      flag = FeatureFlags.get_flag!(:my_test_flag)
      assert flag.name == :my_test_flag
    end

    test "returns a flag by string name" do
      feature_flag_fixture(%{name: "my_string_flag"})
      flag = FeatureFlags.get_flag!("my_string_flag")
      assert flag.name == :my_string_flag
    end

    test "raises on unknown flag" do
      assert_raise RuntimeError, fn ->
        FeatureFlags.get_flag!(:nonexistent_flag_xyz)
      end
    end
  end

  describe "create_flag/2" do
    test "creates a disabled flag" do
      admin = admin_fixture()
      {:ok, flag} = FeatureFlags.create_flag(%{name: "new_flag"}, admin)
      assert flag.name == :new_flag
      refute FeatureFlags.boolean_enabled?(flag)
    end

    test "emits an audit log entry" do
      admin = admin_fixture()
      {:ok, _flag} = FeatureFlags.create_flag(%{name: "audited_flag"}, admin)
      [audit] = Repo.all(AuditLog)
      assert audit.action == "create_feature_flag"
    end

    test "rejects invalid names" do
      admin = admin_fixture()
      assert {:error, :invalid_name} = FeatureFlags.create_flag(%{name: "UPPER"}, admin)
    end
  end

  describe "set_enabled/3" do
    test "enables a flag" do
      admin = admin_fixture()
      flag = feature_flag_fixture(%{name: "toggle_me"})
      {:ok, updated} = FeatureFlags.set_enabled(flag, true, admin)
      assert FeatureFlags.boolean_enabled?(updated)
    end

    test "disables a flag" do
      admin = admin_fixture()
      flag = feature_flag_fixture(%{name: "disable_me", enabled: true})
      {:ok, updated} = FeatureFlags.set_enabled(flag, false, admin)
      refute FeatureFlags.boolean_enabled?(updated)
    end

    test "emits a toggle audit log entry" do
      admin = admin_fixture()
      flag = feature_flag_fixture(%{name: "audit_toggle"})
      {:ok, _} = FeatureFlags.set_enabled(flag, true, admin)
      audits = Repo.all(AuditLog)
      assert Enum.any?(audits, &(&1.action == "toggle_feature_flag"))
    end
  end

  describe "enabled?/2" do
    test "returns false for a disabled flag" do
      feature_flag_fixture(%{name: "disabled_check"})
      user = user_fixture()
      refute FeatureFlags.enabled?(:disabled_check, user)
    end

    test "returns true for an enabled flag" do
      feature_flag_fixture(%{name: "enabled_check", enabled: true})
      user = user_fixture()
      assert FeatureFlags.enabled?(:enabled_check, user)
    end

    test "returns false for a nonexistent flag" do
      user = user_fixture()
      refute FeatureFlags.enabled?("nonexistent_flag_abc", user)
    end
  end

  describe "boolean_enabled?/1" do
    test "returns true when boolean gate is enabled" do
      flag = feature_flag_fixture(%{name: "bool_on", enabled: true})
      assert FeatureFlags.boolean_enabled?(flag)
    end

    test "returns false when boolean gate is disabled" do
      flag = feature_flag_fixture(%{name: "bool_off"})
      refute FeatureFlags.boolean_enabled?(flag)
    end
  end

  describe "gate_summary/1" do
    test "returns :global for a flag with only boolean gate" do
      flag = feature_flag_fixture(%{name: "global_flag"})
      assert {:global, nil} = FeatureFlags.gate_summary(flag)
    end

    test "returns :percentage with value for percentage gate" do
      flag =
        feature_flag_fixture(%{name: "pct_flag", strategy: "percentage", percentage: 42})

      assert {:percentage, 42} = FeatureFlags.gate_summary(flag)
    end
  end

  describe "percentage determinism" do
    test "same subject always gets the same decision" do
      feature_flag_fixture(%{
        name: "pct_stable",
        strategy: "percentage",
        percentage: 50,
        enabled: true
      })

      user = user_fixture()
      a = FeatureFlags.enabled?(:pct_stable, user)
      b = FeatureFlags.enabled?(:pct_stable, user)
      assert a == b
    end
  end
end
