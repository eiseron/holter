defmodule HolterWeb.Api.DeliveryApiSpecTest do
  use ExUnit.Case, async: true

  alias HolterWeb.Api.DeliveryApiSpec

  describe "spec/0" do
    test "spec title is Holter Delivery API" do
      assert DeliveryApiSpec.spec().info.title == "Holter Delivery API"
    end

    test "only delivery paths (webhook_channel or email_channel) are included" do
      assert Enum.all?(Map.keys(DeliveryApiSpec.spec().paths), fn path ->
               String.contains?(path, "webhook_channel") or
                 String.contains?(path, "email_channel")
             end)
    end

    test "schemas include a WebhookChannel entry" do
      assert Enum.any?(
               Map.keys(DeliveryApiSpec.spec().components.schemas),
               &String.contains?(&1, "WebhookChannel")
             )
    end

    test "schemas include an EmailChannel entry" do
      assert Enum.any?(
               Map.keys(DeliveryApiSpec.spec().components.schemas),
               &String.contains?(&1, "EmailChannel")
             )
    end
  end
end
