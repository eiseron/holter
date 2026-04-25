defmodule Holter.Delivery.NotificationChannelSsrfTest do
  use Holter.DataCase, async: true

  alias Holter.Delivery.NotificationChannel

  defp webhook_changeset(target) do
    %NotificationChannel{}
    |> NotificationChannel.changeset(%{
      workspace_id: Ecto.UUID.generate(),
      name: "Hook",
      type: :webhook,
      target: target
    })
  end

  defp email_changeset(target) do
    %NotificationChannel{}
    |> NotificationChannel.changeset(%{
      workspace_id: Ecto.UUID.generate(),
      name: "Email",
      type: :email,
      target: target
    })
  end

  describe "webhook SSRF — blocked targets" do
    test "localhost is rejected" do
      cs = webhook_changeset("http://localhost/hook")
      assert "must be a valid http or https URL" in errors_on(cs).target
    end

    test "127.0.0.1 loopback is rejected" do
      cs = webhook_changeset("http://127.0.0.1/hook")
      assert "must be a valid http or https URL" in errors_on(cs).target
    end

    test "127.x.x.x range is rejected" do
      cs = webhook_changeset("http://127.255.255.255/hook")
      assert "must be a valid http or https URL" in errors_on(cs).target
    end

    test "0.0.0.0 unspecified address is rejected" do
      cs = webhook_changeset("http://0.0.0.0/hook")
      assert "must be a valid http or https URL" in errors_on(cs).target
    end

    test "10.x.x.x RFC1918 is rejected" do
      cs = webhook_changeset("http://10.0.0.1/hook")
      assert "must be a valid http or https URL" in errors_on(cs).target
    end

    test "172.16.x.x RFC1918 lower bound is rejected" do
      cs = webhook_changeset("http://172.16.0.1/hook")
      assert "must be a valid http or https URL" in errors_on(cs).target
    end

    test "172.31.x.x RFC1918 upper bound is rejected" do
      cs = webhook_changeset("http://172.31.255.255/hook")
      assert "must be a valid http or https URL" in errors_on(cs).target
    end

    test "192.168.x.x RFC1918 is rejected" do
      cs = webhook_changeset("http://192.168.1.1/hook")
      assert "must be a valid http or https URL" in errors_on(cs).target
    end

    test "169.254.169.254 cloud metadata endpoint is rejected" do
      cs = webhook_changeset("http://169.254.169.254/latest/meta-data")
      assert "must be a valid http or https URL" in errors_on(cs).target
    end

    test "169.254.x.x link-local range is rejected" do
      cs = webhook_changeset("http://169.254.0.1/hook")
      assert "must be a valid http or https URL" in errors_on(cs).target
    end

    test "IPv6 loopback ::1 is rejected" do
      cs = webhook_changeset("http://[::1]/hook")
      assert "must be a valid http or https URL" in errors_on(cs).target
    end

    test "IPv6 unspecified :: is rejected" do
      cs = webhook_changeset("http://[::]/hook")
      assert "must be a valid http or https URL" in errors_on(cs).target
    end
  end

  describe "webhook SSRF — allowed targets" do
    test "public https URL is accepted" do
      cs = webhook_changeset("https://example.com/hook")
      assert cs.valid?
    end

    test "public http URL is accepted" do
      cs = webhook_changeset("http://hooks.example.com/notify")
      assert cs.valid?
    end

    test "public URL with port is accepted" do
      cs = webhook_changeset("https://api.external-service.com:8443/events")
      assert cs.valid?
    end

    test "172.15.x.x (just below RFC1918 range) is accepted" do
      cs = webhook_changeset("http://172.15.255.255/hook")
      assert cs.valid?
    end

    test "172.32.x.x (just above RFC1918 range) is accepted" do
      cs = webhook_changeset("http://172.32.0.1/hook")
      assert cs.valid?
    end
  end

  describe "email type is unaffected by SSRF rules" do
    test "valid email address is accepted" do
      cs = email_changeset("ops@example.com")
      assert cs.valid?
    end
  end
end
