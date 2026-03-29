defmodule HolterWeb.CoreComponents.Form do
  @moduledoc """
  Core Form components with Sentinel Ethos.
  """
  use Phoenix.Component
  use Gettext, backend: HolterWeb.Gettext

  @doc """
  Renders an input with label and error messages.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"
  attr :help, :string, default: nil, doc: "contextual help text displayed on hover of the (?) icon"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="h-form-group">
      <label class="h-form-checkbox">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={@class || ""}
          {@rest}
        />
        <span class="h-label-text">
          {@label}
          <span :if={@help} class="h-form-help-icon ml-2">
            ?
            <span class="h-form-tooltip">{@help}</span>
          </span>
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="h-form-group">
      <label class="h-form-label">
        <span :if={@label}>{@label}</span>
        <span :if={@help} class="h-form-help-icon">
          ?
          <span class="h-form-tooltip">{@help}</span>
        </span>
      </label>
      <select
        id={@id}
        name={@name}
        class={[@class || "h-form-select", @errors != [] && (@error_class || "is-error")]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="h-form-group">
      <label class="h-form-label">
        <span :if={@label}>{@label}</span>
        <span :if={@help} class="h-form-help-icon">
          ?
          <span class="h-form-tooltip">{@help}</span>
        </span>
      </label>
      <textarea
        id={@id}
        name={@name}
        class={[
          @class || "h-form-textarea",
          @errors != [] && (@error_class || "is-error")
        ]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="h-form-group">
      <label class="h-form-label">
        <span :if={@label}>{@label}</span>
        <span :if={@help} class="h-form-help-icon">
          ?
          <span class="h-form-tooltip">{@help}</span>
        </span>
      </label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          @class || "h-form-input",
          @errors != [] && (@error_class || "is-error")
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders a form label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="h-form-label">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates form errors.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="h-form-error">
      {render_slot(@inner_block)}
    </p>
    """
  end

  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(HolterWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(HolterWeb.Gettext, "errors", msg, opts)
    end
  end

  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
