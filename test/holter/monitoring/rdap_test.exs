defmodule Holter.Monitoring.RdapTest do
  use ExUnit.Case, async: true

  alias Holter.Monitoring.Rdap

  describe "parse_expiration/1" do
    test "returns the expiration datetime when an expiration event is present" do
      response = %{
        "events" => [
          %{"eventAction" => "registration", "eventDate" => "1995-08-14T04:00:00Z"},
          %{"eventAction" => "expiration", "eventDate" => "2027-01-15T00:00:00Z"}
        ]
      }

      assert {:ok, ~U[2027-01-15 00:00:00Z]} = Rdap.parse_expiration(response)
    end

    test "returns an error when no expiration event is present" do
      response = %{
        "events" => [
          %{"eventAction" => "registration", "eventDate" => "1995-08-14T04:00:00Z"}
        ]
      }

      assert {:error, :no_expiration_event} = Rdap.parse_expiration(response)
    end

    test "returns an error when the events key is missing" do
      assert {:error, :no_expiration_event} =
               Rdap.parse_expiration(%{"objectClassName" => "domain"})
    end

    test "returns an error when the events value is not a list" do
      assert {:error, :no_expiration_event} = Rdap.parse_expiration(%{"events" => "nope"})
    end

    test "returns an error when the expiration eventDate is malformed" do
      response = %{
        "events" => [
          %{"eventAction" => "expiration", "eventDate" => "not-a-date"}
        ]
      }

      assert {:error, :invalid_event_date} = Rdap.parse_expiration(response)
    end

    test "returns an error when the expiration eventDate is not a string" do
      response = %{
        "events" => [
          %{"eventAction" => "expiration", "eventDate" => 12_345}
        ]
      }

      assert {:error, :invalid_event_date} = Rdap.parse_expiration(response)
    end
  end
end
