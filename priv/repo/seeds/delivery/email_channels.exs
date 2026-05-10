defmodule Holter.Seeds.Delivery.EmailChannels do
  @moduledoc false

  alias Holter.Delivery.EmailChannels

  alias Holter.Delivery.Models.{EmailChannel, EmailChannelRecipient}
  alias Holter.Repo

  def create_for(workspace, monitors) do
    engineering = create_channel(workspace, "Engineering team")
    add_verified_recipient(engineering, "alerts@dev.example.com")
    add_verified_recipient(engineering, "alice@dev.example.com")
    add_verified_recipient(engineering, "bob@dev.example.com")

    on_call = create_channel(workspace, "On-call rotation")
    add_verified_recipient(on_call, "oncall@dev.example.com")
    add_verified_recipient(on_call, "alice@dev.example.com")
    add_pending_recipient(on_call, "carol@dev.example.com")

    stakeholders = create_channel(workspace, "Stakeholders", locale: "en")
    add_pending_recipient(stakeholders, "stakeholders@dev.example.com")

    Enum.each(active_monitors(monitors), fn monitor ->
      {:ok, _} = EmailChannels.link_monitor(monitor.id, engineering.id)
    end)

    Enum.each(critical_monitors(monitors), fn monitor ->
      {:ok, _} = EmailChannels.link_monitor(monitor.id, on_call.id)
    end)

    IO.puts(
      "[seeds] Created 3 email channels (2 with verified recipients, 1 awaiting verification)"
    )

    %{engineering: engineering, on_call: on_call, stakeholders: stakeholders}
  end

  defp create_channel(workspace, name, opts \\ []) do
    attrs =
      %{workspace_id: workspace.id, name: name}
      |> Map.merge(Map.new(opts))

    %EmailChannel{}
    |> EmailChannel.changeset(attrs)
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
