Mox.defmock(Holter.Monitoring.MonitorClientMock, for: Holter.Monitoring.MonitorClient)

{:ok, _} = Holter.Test.DummyService.start_link([])
{:ok, _} = Bandit.start_link(plug: Holter.Test.DummyService, port: 4001)
Application.put_env(:holter, :dummy_port, 4001)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Holter.Repo, :manual)
