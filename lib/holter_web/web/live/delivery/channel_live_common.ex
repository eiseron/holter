defmodule HolterWeb.Web.Delivery.ChannelLiveCommon do
  @moduledoc """
  Shared LiveView helpers for the per-type channel show pages.

  Both `WebhookChannelLive.Show` and `EmailChannelLive.Show` carry the same
  Send-Test-cooldown countdown — assign-on-mount, decrement on `:tick`, schedule
  the next tick. Centralized here so the two LiveViews don't drift.
  """
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [connected?: 1]

  alias Holter.Delivery.Engine

  @doc """
  Sets `:cooldown_remaining` based on `last_test_dispatched_at` and the
  configured cooldown. If a positive cooldown is computed and the LiveView
  is connected, schedules the first `:tick` message.
  """
  def assign_test_cooldown(socket, nil), do: assign(socket, :cooldown_remaining, 0)

  def assign_test_cooldown(socket, %DateTime{} = last) do
    diff = DateTime.diff(DateTime.utc_now(), last, :second)
    remaining = max(0, Engine.test_dispatch_cooldown() - diff)
    already_ticking = Map.get(socket.assigns, :cooldown_remaining, 0) > 0

    if remaining > 0 and not already_ticking and connected?(socket) do
      Process.send_after(self(), :tick, 1000)
    end

    assign(socket, :cooldown_remaining, remaining)
  end

  @doc """
  Drops the cooldown by one second; reschedules the next tick if still > 0.
  Call from `handle_info(:tick, socket)` in each LiveView.
  """
  def handle_tick(socket) do
    new_cooldown = max(0, socket.assigns.cooldown_remaining - 1)

    if new_cooldown > 0, do: Process.send_after(self(), :tick, 1000)

    assign(socket, :cooldown_remaining, new_cooldown)
  end
end
