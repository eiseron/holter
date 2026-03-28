defmodule Holter.Monitoring.MonitorLogTest do
  use Holter.DataCase, async: true
  alias Holter.Monitoring.MonitorLog

  @valid_attrs %{
    status: :up,
    http_status: 200,
    response_time_ms: 150,
    checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
  }

  test "Given valid attributes, when cast, then the changeset is valid" do
    changeset = MonitorLog.changeset(%MonitorLog{}, Map.put(@valid_attrs, :monitor_id, Ecto.UUID.generate()))
    assert changeset.valid?
  end

  test "Given missing required fields, when cast, then the changeset is invalid" do
    changeset = MonitorLog.changeset(%MonitorLog{}, %{})
    refute changeset.valid?
    assert %{monitor_id: ["can't be blank"], status: ["can't be blank"], checked_at: ["can't be blank"]} = errors_on(changeset)
  end
end
