defmodule HolterWeb.Web.Dev.EmailPreviewLive do
  @moduledoc """
  Dev-only browser for every notification email template, mounted at
  `/dev/emails`. Each entry in the sidebar drives the real `build_*`
  function with fixture data so the surface exercises the same code path
  production sends through. The compile-time `dev_routes` flag keeps this
  view out of the prod build.
  """
  use HolterWeb, :live_view

  alias Holter.Emails.Previews
  alias Holter.Mailers.{AlertMailer, InfoMailer}

  @delivery_keys ~w(recipient_verification alert_down alert_up alert_test)a

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:previews, Previews.list())
     |> assign(:locales, Previews.locales())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    locale = params["locale"] || "en"
    view_mode = params["view"] || "html"

    selected = resolve_selection(params["preview_key"], params["variant_key"])
    email = if selected, do: Previews.build(selected.preview_key, selected.variant_key, locale)

    {:noreply,
     socket
     |> assign(:locale, locale)
     |> assign(:view_mode, view_mode)
     |> assign(:selected, selected)
     |> assign(:email, email)}
  end

  @impl true
  def handle_event("select_view", %{"view" => view}, socket) do
    {:noreply, push_patch(socket, to: link_to(socket, view: view))}
  end

  def handle_event("select_locale", %{"locale" => locale}, socket) do
    {:noreply, push_patch(socket, to: link_to(socket, locale: locale))}
  end

  def handle_event("send_to_mailbox", _params, socket) do
    case socket.assigns.email do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a template first.")}

      email ->
        mailer_for(socket.assigns.selected.preview_key).deliver(email)
        {:noreply, put_flash(socket, :info, "Sent to /dev/mailbox")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display: grid; grid-template-columns: 320px 1fr; min-height: 100vh; background: #0f172a; color: #f8fafc;">
      <aside style="background: #1e293b; padding: 20px; border-right: 1px solid #334155; overflow-y: auto;">
        <h1 style="margin: 0 0 16px 0; font-size: 18px;">Email previews</h1>
        <p style="margin: 0 0 16px 0; font-size: 12px; color: #94a3b8;">
          Dev-only. Renders every notification template against fixture data.
        </p>

        <%= for group <- [:identity, :delivery] do %>
          <h2 style="margin: 16px 0 8px 0; font-size: 11px; text-transform: uppercase; color: #94a3b8; letter-spacing: 0.05em;">
            {group}
          </h2>
          <ul style="list-style: none; padding: 0; margin: 0;">
            <%= for preview <- Enum.filter(@previews, &(&1.group == group)) do %>
              <li style="margin-bottom: 12px;">
                <div style="font-size: 13px; font-weight: 600; color: #e2e8f0;">
                  {preview.label}
                </div>
                <ul style="list-style: none; padding: 0; margin: 4px 0 0 0;">
                  <li :for={variant <- preview.variants} style="padding: 2px 0;">
                    <.link
                      patch={
                        preview_link(%{
                          preview_key: preview.key,
                          variant_key: variant.key,
                          locale: @locale,
                          view: @view_mode
                        })
                      }
                      style={"font-size: 13px; #{variant_link_style(@selected, preview.key, variant.key)}"}
                    >
                      {variant.label}
                    </.link>
                  </li>
                </ul>
              </li>
            <% end %>
          </ul>
        <% end %>
      </aside>

      <main style="display: flex; flex-direction: column; min-width: 0;">
        <header style="padding: 16px 20px; border-bottom: 1px solid #334155; background: #1e293b; display: flex; gap: 12px; align-items: center; flex-wrap: wrap;">
          <strong :if={@selected} style="font-size: 14px;">
            {selected_label(@previews, @selected)}
          </strong>
          <span :if={!@selected} style="color: #94a3b8;">
            Pick a template from the sidebar.
          </span>

          <div
            :if={@selected}
            style="margin-left: auto; display: flex; gap: 8px; align-items: center;"
          >
            <label style="font-size: 12px; color: #94a3b8;">Locale</label>
            <form phx-change="select_locale">
              <select
                name="locale"
                style="background: #0f172a; color: #f8fafc; border: 1px solid #334155; padding: 4px 8px; border-radius: 4px;"
              >
                <option :for={loc <- @locales} value={loc} selected={loc == @locale}>
                  {loc}
                </option>
              </select>
            </form>

            <div
              role="tablist"
              style="display: inline-flex; border: 1px solid #334155; border-radius: 4px; overflow: hidden;"
            >
              <button
                :for={mode <- ~w(html text headers)}
                type="button"
                phx-click="select_view"
                phx-value-view={mode}
                style={"padding: 4px 12px; font-size: 12px; background: #{view_button_bg(@view_mode, mode)}; color: #f8fafc; border: none; cursor: pointer;"}
              >
                {mode}
              </button>
            </div>

            <button
              type="button"
              phx-click="send_to_mailbox"
              style="padding: 6px 14px; font-size: 12px; background: #37b9ff; color: #0f172a; border: none; border-radius: 4px; cursor: pointer; font-weight: 600;"
            >
              Send to /dev/mailbox
            </button>
          </div>
        </header>

        <section style="flex: 1; padding: 20px; overflow: auto;">
          <div :if={!@selected} style="color: #94a3b8;">
            Each entry runs the real <code>build_*</code> function with fixture data.
            Locale and view-mode toggles are reflected in the URL so previews are shareable.
          </div>

          <iframe
            :if={@selected && @view_mode == "html"}
            srcdoc={@email.html_body}
            sandbox="allow-same-origin"
            style="width: 100%; height: calc(100vh - 140px); background: #ffffff; border: 1px solid #334155; border-radius: 6px;"
          >
          </iframe>

          <pre
            :if={@selected && @view_mode == "text"}
            style="white-space: pre-wrap; background: #1e293b; padding: 16px; border-radius: 6px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 13px; line-height: 1.5;"
          ><%= @email.text_body %></pre>

          <dl
            :if={@selected && @view_mode == "headers"}
            style="background: #1e293b; padding: 16px; border-radius: 6px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 13px;"
          >
            <dt style="color: #94a3b8;">Subject</dt>
            <dd style="margin: 4px 0 12px 0;">{@email.subject}</dd>
            <dt style="color: #94a3b8;">From</dt>
            <dd style="margin: 4px 0 12px 0;">{format_address(@email.from)}</dd>
            <dt style="color: #94a3b8;">To</dt>
            <dd style="margin: 4px 0 0 0;">
              {@email.to |> Enum.map(&format_address/1) |> Enum.join(", ")}
            </dd>
          </dl>
        </section>
      </main>
    </div>
    """
  end

  defp resolve_selection(nil, _), do: nil
  defp resolve_selection(_, nil), do: nil

  defp resolve_selection(preview_key_str, variant_key_str) do
    preview_key = safe_atom(preview_key_str)
    variant_key = safe_atom(variant_key_str)

    if preview_key && variant_key && Previews.find(preview_key, variant_key) do
      %{preview_key: preview_key, variant_key: variant_key}
    end
  end

  defp safe_atom(string) do
    String.to_existing_atom(string)
  rescue
    ArgumentError -> nil
  end

  defp mailer_for(key) when key in @delivery_keys, do: AlertMailer
  defp mailer_for(_), do: InfoMailer

  defp link_to(socket, overrides) do
    selected = socket.assigns.selected
    locale = Keyword.get(overrides, :locale, socket.assigns.locale)
    view = Keyword.get(overrides, :view, socket.assigns.view_mode)

    base =
      case selected do
        nil -> ~p"/dev/emails"
        %{preview_key: pk, variant_key: vk} -> ~p"/dev/emails/#{pk}/#{vk}"
      end

    base <> "?" <> URI.encode_query(locale: locale, view: view)
  end

  defp preview_link(%{preview_key: pk, variant_key: vk, locale: locale, view: view}) do
    ~p"/dev/emails/#{pk}/#{vk}" <> "?" <> URI.encode_query(locale: locale, view: view)
  end

  defp variant_link_style(nil, _, _), do: "color: #cbd5e1;"

  defp variant_link_style(%{preview_key: pk, variant_key: vk}, pk, vk),
    do: "color: #37b9ff; font-weight: 600;"

  defp variant_link_style(_, _, _), do: "color: #cbd5e1;"

  defp view_button_bg(active, active), do: "#37b9ff"
  defp view_button_bg(_, _), do: "transparent"

  defp selected_label(previews, %{preview_key: pk, variant_key: vk}) do
    preview = Enum.find(previews, &(&1.key == pk))
    variant = Enum.find(preview.variants, &(&1.key == vk))

    "#{preview.label} — #{variant.label}"
  end

  defp format_address({"", addr}), do: addr
  defp format_address({name, addr}), do: "#{name} <#{addr}>"
  defp format_address(addr) when is_binary(addr), do: addr
end
