defmodule HolterWeb.Components.Monitoring.MonitorFormFields do
  @moduledoc false
  use HolterWeb, :component

  import HolterWeb.Components.Input

  alias Holter.Monitoring.Monitor

  @doc """
  Renders the technical configuration fieldset for a monitor form.
  """
  attr :form, :any, required: true

  def monitor_form_technical(assigns) do
    ~H"""
    <div class="h-fieldset-card">
      <h3 class="h-fieldset-legend">{gettext("Technical Configuration")}</h3>
      <div class="h-form-grid h-grid-cols-2">
        <div>
          <.input
            field={@form[:url]}
            type="url"
            label={gettext("URL")}
            placeholder="https://example.com"
            required
          />
          <p class="h-help-text">
            {gettext("The precise target endpoint or website you want to monitor.")}
          </p>
        </div>

        <div>
          <.input
            field={@form[:method]}
            type="select"
            label={gettext("Method")}
            options={
              Monitor.http_methods()
              |> Enum.map(fn m -> {String.upcase(to_string(m)), to_string(m)} end)
            }
            required
          />
          <p class="h-help-text">{gettext("The HTTP method to use for the request.")}</p>
        </div>

        <div class="h-col-span-2">
          <.input
            field={@form[:raw_headers]}
            type="textarea"
            label={gettext("Custom Headers (JSON)")}
            placeholder={~s|{"Authorization": "Bearer token"}|}
          />
          <p class="h-help-text">
            {gettext("Additional HTTP headers formatted as a valid JSON object.")}
          </p>
        </div>

        <div class="h-col-span-2" :if={not body_hidden?(@form)}>
          <.input
            field={@form[:body]}
            type="textarea"
            label={gettext("Request Body")}
            placeholder={~s|{"my_key": "my_value"}|}
          />
          <p class="h-help-text">
            {gettext("Payload to send with POST/PUT requests (JSON, text, XML).")}
          </p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders the security and validation rules fieldset for a monitor form.
  """
  attr :form, :any, required: true

  def monitor_form_security(assigns) do
    ~H"""
    <div class="h-fieldset-card">
      <h3 class="h-fieldset-legend">{gettext("Security & Validation Rules")}</h3>
      <div class="h-form-grid h-grid-cols-2">
        <div>
          <.input
            field={@form[:raw_keyword_positive]}
            type="text"
            label={gettext("Must Contain (Keywords)")}
            placeholder={gettext("Brand Name, Title, Success")}
          />
          <p class="h-help-text">
            {gettext(
              "The endpoint response MUST contain these words, otherwise it is considered DOWN. Separate multiple words by comma."
            )}
          </p>
        </div>

        <div>
          <.input
            field={@form[:raw_keyword_negative]}
            type="text"
            label={gettext("Must Not Contain (Defacement)")}
            placeholder={gettext("hacked, database error")}
          />
          <p class="h-help-text">
            {gettext(
              "The endpoint response MUST NOT contain these words. Useful to detect hacks/defacements. Separate by comma."
            )}
          </p>
        </div>

        <div class="h-col-span-2">
          <.input
            field={@form[:ssl_ignore]}
            type="checkbox"
            label={gettext("Ignore SSL Validation Errors")}
          />
          <p class="h-help-text">
            {gettext("Check this if your endpoint uses self-signed certificates or expired SSL.")}
          </p>
        </div>

        <div>
          <.input
            field={@form[:follow_redirects]}
            type="checkbox"
            label={gettext("Follow Redirects")}
          />
          <p class="h-help-text">
            {gettext("If the URL responds with a 3xx status, follow the Location header.")}
          </p>
        </div>

        <div :if={not redirects_hidden?(@form)}>
          <.input
            field={@form[:max_redirects]}
            type="number"
            label={gettext("Max Redirects")}
            min="1"
            max="20"
          />
          <p class="h-help-text">
            {gettext("Maximum number of sequential redirects to follow (1-20).")}
          </p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders the interval and timing fieldset for a monitor form.
  """
  attr :form, :any, required: true
  attr :show_logical_state, :boolean, default: false
  attr :min_interval_seconds, :integer, default: nil

  def monitor_form_interval(assigns) do
    assigns =
      assign(
        assigns,
        :effective_min,
        assigns[:min_interval_seconds] || Monitor.interval_min_seconds()
      )

    ~H"""
    <div class="h-fieldset-card">
      <h3 class="h-fieldset-legend">{gettext("Interval Defaults")}</h3>
      <div class={"h-form-grid #{if @show_logical_state, do: "h-grid-cols-3", else: "h-grid-cols-2"}"}>
        <div>
          <label class="h-label-text">{gettext("Check Interval")}</label>
          <div class="h-range-field">
            <input
              type="range"
              id={@form[:interval_seconds].id}
              name={@form[:interval_seconds].name}
              min={@effective_min}
              max={Monitor.interval_max_seconds()}
              step="60"
              value={field_integer(@form[:interval_seconds], @effective_min)}
              class="h-range-input"
              phx-debounce="300"
              oninput="this.nextElementSibling.textContent = (this.value / 60) + ' min'"
            />
            <span class="h-range-value">
              {div(field_integer(@form[:interval_seconds], @effective_min), 60)} min
            </span>
          </div>
          <p class="h-help-text">
            {gettext("How frequently our worker nodes will ping your URL.")}
          </p>
        </div>

        <div>
          <.input
            field={@form[:timeout_seconds]}
            type="number"
            label={gettext("Timeout Threshold (Seconds)")}
            required
          />
          <p class="h-help-text">
            {gettext("Maximum time to wait for a response before declaring the endpoint DOWN.")}
          </p>
        </div>

        <div :if={@show_logical_state}>
          <.input
            field={@form[:logical_state]}
            type="select"
            label={gettext("Monitor State")}
            options={[{gettext("Active"), "active"}, {gettext("Paused"), "paused"}]}
            required
          />
        </div>
      </div>
    </div>
    """
  end

  defp redirects_hidden?(form) do
    form[:follow_redirects].value in [false, "false"]
  end

  defp body_hidden?(form) do
    method = to_string(form[:method].value)
    method in Enum.map(Monitor.bodyless_methods(), &to_string/1)
  end

  defp field_integer(field, fallback) do
    case field.value do
      v when is_integer(v) -> v
      v when is_binary(v) -> String.to_integer(v)
      _ -> fallback
    end
  end
end
