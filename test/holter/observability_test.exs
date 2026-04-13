defmodule Holter.ObservabilityTest do
  use ExUnit.Case, async: true
  alias Holter.Observability

  setup do
    %{versions: Observability.system_versions()}
  end

  test "includes holter_version", %{versions: v} do
    assert Map.has_key?(v, :holter_version)
  end

  test "includes elixir_version", %{versions: v} do
    assert Map.has_key?(v, :elixir_version)
  end

  test "includes otp_version", %{versions: v} do
    assert Map.has_key?(v, :otp_version)
  end

  test "includes phoenix_version", %{versions: v} do
    assert Map.has_key?(v, :phoenix_version)
  end

  test "includes node", %{versions: v} do
    assert Map.has_key?(v, :node)
  end

  test "includes hostname", %{versions: v} do
    assert Map.has_key?(v, :hostname)
  end

  test "holter_version is a string", %{versions: v} do
    assert is_binary(v.holter_version)
  end

  test "elixir_version is a string", %{versions: v} do
    assert is_binary(v.elixir_version)
  end

  test "otp_version is a string", %{versions: v} do
    assert is_binary(v.otp_version)
  end

  test "phoenix_version is a string", %{versions: v} do
    assert is_binary(v.phoenix_version)
  end

  test "node is a string", %{versions: v} do
    assert is_binary(v.node)
  end

  test "hostname is a string", %{versions: v} do
    assert is_binary(v.hostname)
  end
end
