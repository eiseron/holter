defmodule HolterWeb.Components.Delivery.SecretCard do
  @moduledoc """
  Compact card displaying a server-generated secret (webhook signing token,
  email anti-phishing code) with a hide-by-default reveal toggle and Copy /
  Regenerate actions.
  """
  use HolterWeb, :component

  attr :id, :string,
    required: true,
    doc:
      ~s(Base id of the card. Used for "{id}-heading" on the title and ) <>
        ~s("{id}-value" on the code element so callers can target them in tests.)

  attr :title, :string, required: true
  attr :help, :string, required: true
  attr :reveal_label, :string, required: true
  attr :value, :string, required: true

  attr :regenerate_modal_id, :string,
    default: "regenerate-secret-modal",
    doc: "Id of the confirmation modal opened when the user clicks Regenerate."

  def secret_card(assigns) do
    ~H"""
    <section class="h-secret-card" aria-labelledby={"#{@id}-heading"}>
      <h3 id={"#{@id}-heading"} class="h-secret-card__title">
        {@title}
      </h3>
      <p class="h-secret-card__help">{@help}</p>

      <details class="h-secret-card__reveal">
        <summary>{@reveal_label}</summary>
        <pre
          id={"#{@id}-value"}
          data-testid={"#{@id}-value"}
          class="h-secret-card__code"
        ><code>{@value}</code></pre>
      </details>

      <div class="h-secret-card__actions">
        <button
          type="button"
          class="h-btn h-btn-danger"
          phx-click={JS.remove_attribute("hidden", to: "##{@regenerate_modal_id}")}
        >
          {gettext("Regenerate")}
        </button>
        <button
          type="button"
          class="h-btn h-btn-soft"
          onclick={
            "navigator.clipboard.writeText(document.getElementById('#{@id}-value').textContent.trim())"
          }
        >
          {gettext("Copy")}
        </button>
      </div>
    </section>
    """
  end
end
