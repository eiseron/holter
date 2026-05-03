defmodule Holter.Seeds.Delivery.EmailChannels do
  @moduledoc false

  alias Holter.Delivery.{EmailChannel, EmailChannelRecipient, EmailChannels}
  alias Holter.Repo
  alias Holter.Seeds.Time

  @day Time.day()

  def create_for(workspace, monitors) do
    engineering = create_verified_channel(workspace, "Engineering team", "alerts@dev.example.com")
    add_verified_recipient(engineering, "alice@dev.example.com")
    add_verified_recipient(engineering, "bob@dev.example.com")

    on_call = create_verified_channel(workspace, "On-call rotation", "oncall@dev.example.com")
    add_verified_recipient(on_call, "alice@dev.example.com")
    add_pending_recipient(on_call, "carol@dev.example.com")

    stakeholders =
      create_unverified_channel(workspace, "Stakeholders", "stakeholders@dev.example.com")

    Enum.each(active_monitors(monitors), fn monitor ->
      {:ok, _} = EmailChannels.link_monitor(monitor.id, engineering.id)
    end)

    Enum.each(critical_monitors(monitors), fn monitor ->
      {:ok, _} = EmailChannels.link_monitor(monitor.id, on_call.id)
    end)

    IO.puts(
      "[seeds] Created 3 email channels (2 verified with recipients, 1 awaiting verification)"
    )

    %{engineering: engineering, on_call: on_call, stakeholders: stakeholders}
  end

  defp create_verified_channel(workspace, name, address) do
    %EmailChannel{}
    |> EmailChannel.changeset(%{workspace_id: workspace.id, name: name, address: address})
    |> Ecto.Changeset.put_change(:verified_at, Time.ago(10 * @day))
    |> Repo.insert!()
  end

  defp create_unverified_channel(workspace, name, address) do
    %EmailChannel{}
    |> EmailChannel.changeset(%{workspace_id: workspace.id, name: name, address: address})
    |> Repo.insert!()
  end

  defp add_verified_recipient(channel, email) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    %EmailChannelRecipient{}
    |> EmailChannelRecipient.changeset(%{
      email_channel_id: channel.id,
      email: email,
      verified_at: now
    })
    |> Repo.insert!()
  end

  defp add_pending_recipient(channel, email) do
    token = EmailChannelRecipient.generate_token()
    expires_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(48 * 3600, :second)

    %EmailChannelRecipient{}
    |> EmailChannelRecipient.changeset(%{
      email_channel_id: channel.id,
      email: email,
      token: token,
      token_expires_at: NaiveDateTime.truncate(expires_at, :second)
    })
    |> Repo.insert!()
  end

  defp active_monitors(m) do
    [m.healthy_example, m.healthy_github, m.down, m.degraded, m.ssl_expiring, m.domain_expiring]
  end

  defp critical_monitors(m), do: [m.down, m.degraded, m.ssl_expiring]
end
