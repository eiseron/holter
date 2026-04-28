Mox.defmock(Holter.Monitoring.MonitorClientMock, for: Holter.Monitoring.MonitorClient)
Mox.defmock(Holter.Delivery.HttpClientMock, for: Holter.Delivery.HttpClient)
Mox.defmock(Holter.Network.ResolverMock, for: Holter.Network.Resolver)

{:ok, _} = Holter.Test.DummyService.start_link([])
{:ok, _} = Bandit.start_link(plug: Holter.Test.DummyService, port: 4001)
Application.put_env(:holter, :dummy_port, 4001)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Holter.Repo, :manual)

:logger.set_application_level(:db_connection, :critical)
