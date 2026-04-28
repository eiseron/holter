defmodule Holter.Delivery.WebhookChannelTest do
  use Holter.DataCase, async: true

  alias Holter.Delivery
  alias Holter.Delivery.WebhookChannel
  alias Holter.Repo

  describe "changeset/2" do
    test "is invalid without a url" do
      changeset = WebhookChannel.changeset(%WebhookChannel{}, %{})
      assert "can't be blank" in errors_on(changeset).url
    end

    test "rejects a url longer than 2048 characters" do
      url = "https://example.com/" <> String.duplicate("a", 2050)
      changeset = WebhookChannel.changeset(%WebhookChannel{}, %{url: url})
      assert Enum.any?(errors_on(changeset).url, &String.contains?(&1, "should be at most"))
    end

    test "rejects a url with a non-http scheme" do
      changeset = WebhookChannel.changeset(%WebhookChannel{}, %{url: "ftp://example.com"})
      assert "must be a valid http or https URL" in errors_on(changeset).url
    end

    test "rejects a url with no scheme" do
      changeset = WebhookChannel.changeset(%WebhookChannel{}, %{url: "example.com/hook"})
      assert "must be a valid http or https URL" in errors_on(changeset).url
    end

    test "rejects a url pointing at localhost" do
      changeset = WebhookChannel.changeset(%WebhookChannel{}, %{url: "http://localhost/hook"})
      assert "must be a valid http or https URL" in errors_on(changeset).url
    end

    test "rejects a url pointing at a private IP" do
      changeset = WebhookChannel.changeset(%WebhookChannel{}, %{url: "http://10.0.0.1/hook"})
      assert "must be a valid http or https URL" in errors_on(changeset).url
    end

    test "accepts a public https url" do
      changeset =
        WebhookChannel.changeset(%WebhookChannel{}, %{url: "https://hooks.example.com/abc"})

      refute Map.has_key?(errors_on(changeset), :url)
    end

    test "rejects a url that embeds credentials in its userinfo" do
      changeset =
        WebhookChannel.changeset(%WebhookChannel{}, %{
          url: "http://attacker:pwd@hooks.example.com/abc"
        })

      assert "must not include credentials" in errors_on(changeset).url
    end

    test "rejects a url with embedded CRLF (header-injection shape)" do
      changeset =
        WebhookChannel.changeset(%WebhookChannel{}, %{
          url: "https://hooks.example.com/abc\r\nX-Inject: 1"
        })

      assert "must not contain whitespace or control characters" in errors_on(changeset).url
    end

    test "rejects a url with a tab character" do
      changeset =
        WebhookChannel.changeset(%WebhookChannel{}, %{
          url: "https://hooks.example.com/\tabc"
        })

      assert "must not contain whitespace or control characters" in errors_on(changeset).url
    end
  end

  describe "settings size validation" do
    test "accepts a settings map encoding to under 4 KB" do
      settings = %{"headers" => %{"x-custom" => String.duplicate("a", 1000)}}
      changeset = WebhookChannel.changeset(%WebhookChannel{}, settings_attrs(settings))
      refute Map.has_key?(errors_on(changeset), :settings)
    end

    test "rejects a settings map encoding to more than 4 KB" do
      settings = %{"headers" => %{"x-custom" => String.duplicate("a", 5000)}}
      changeset = WebhookChannel.changeset(%WebhookChannel{}, settings_attrs(settings))

      assert Enum.any?(
               errors_on(changeset).settings,
               &String.contains?(&1, "must be at most 4096 bytes")
             )
    end

    test "accepts a deeply nested settings map of small total size" do
      settings = build_nested(%{}, 50)
      changeset = WebhookChannel.changeset(%WebhookChannel{}, settings_attrs(settings))
      refute Map.has_key?(errors_on(changeset), :settings)
    end
  end

  defp settings_attrs(settings) do
    %{url: "https://hooks.example.com/abc", settings: settings}
  end

  defp build_nested(acc, 0), do: acc
  defp build_nested(acc, n), do: build_nested(%{"k" => acc}, n - 1)

  describe "uniqueness on notification_channel_id" do
    test "a duplicate insert returns an error tuple" do
      assert {:error, %Ecto.Changeset{}} = duplicate_insert()
    end

    test "the duplicate error names the unique constraint field" do
      {:error, changeset} = duplicate_insert()
      assert "has already been taken" in errors_on(changeset).notification_channel_id
    end
  end

  defp duplicate_insert do
    ws = workspace_fixture()

    {:ok, channel} =
      Delivery.create_channel(%{
        workspace_id: ws.id,
        name: "Hook",
        type: :webhook,
        target: "https://example.com/a"
      })

    %WebhookChannel{}
    |> WebhookChannel.changeset(%{
      notification_channel_id: channel.id,
      url: "https://example.com/duplicate"
    })
    |> Repo.insert()
  end
end
