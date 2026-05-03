defmodule Holter.Delivery.NotificationChannelAllowlistTest do
  use Holter.DataCase, async: false

  alias Holter.Delivery.WebhookChannel

  setup do
    previous = Application.get_env(:holter, :network, [])

    Application.put_env(
      :holter,
      :network,
      Keyword.put(previous, :trusted_hosts, ["localhost"])
    )

    on_exit(fn -> Application.put_env(:holter, :network, previous) end)
  end

  defp webhook_changeset(url) do
    %WebhookChannel{}
    |> WebhookChannel.changeset(%{
      workspace_id: Ecto.UUID.generate(),
      name: "Hook",
      url: url
    })
  end

  test "an allowlisted private host is accepted on a webhook channel" do
    cs = webhook_changeset("http://localhost/hook")
    refute Map.has_key?(errors_on(cs), :url)
  end

  test "non-allowlisted private hosts are still rejected" do
    cs = webhook_changeset("http://192.168.1.1/hook")
    assert "must be a valid http or https URL" in errors_on(cs).url
  end
end
