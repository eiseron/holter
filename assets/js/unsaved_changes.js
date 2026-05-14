const FORM_SELECTOR = "form[phx-submit]:not([data-no-warn])"
const TRACKED_ATTR = "data-unsaved-tracked"

const trackedForms = new Set()
const initialSignatures = new WeakMap()
const serverForcedDirty = new WeakSet()

function formSignature(form) {
  const entries = []
  for (const [name, value] of new FormData(form).entries()) {
    if (value instanceof File) continue
    entries.push([name, String(value)])
  }
  entries.sort()
  return JSON.stringify(entries)
}

function snapshot(form) {
  initialSignatures.set(form, formSignature(form))
}

function trackForm(form) {
  if (form.hasAttribute(TRACKED_ATTR)) return
  form.setAttribute(TRACKED_ATTR, "true")

  trackedForms.add(form)
  snapshot(form)

  form.addEventListener("submit", () => {
    serverForcedDirty.delete(form)
    snapshot(form)
  })
}

function scanDocument() {
  document.querySelectorAll(FORM_SELECTOR).forEach(trackForm)
}

function pruneDetachedForms() {
  for (const form of trackedForms) {
    if (!form.isConnected) {
      trackedForms.delete(form)
      serverForcedDirty.delete(form)
    }
  }
}

function isDirty(form) {
  if (serverForcedDirty.has(form)) return true
  const snap = initialSignatures.get(form)
  if (snap === undefined) return false
  return formSignature(form) !== snap
}

function hasDirtyForm() {
  pruneDetachedForms()
  for (const form of trackedForms) {
    if (isDirty(form)) return true
  }
  return false
}

function appConfig() {
  const el = document.getElementById("app-config")
  if (!el || !el.dataset.config) return {}
  try {
    return JSON.parse(el.dataset.config)
  } catch {
    return {}
  }
}

function confirmMessage() {
  return (appConfig().i18n && appConfig().i18n.unsaved_confirm) || ""
}

function onBeforeUnload(event) {
  if (!hasDirtyForm()) return
  event.preventDefault()
  event.returnValue = ""
}

function onCapturedClick(event) {
  if (!hasDirtyForm()) return
  const link = event.target.closest("a[data-phx-link]")
  if (!link) return
  if (window.confirm(confirmMessage())) return
  event.preventDefault()
  event.stopImmediatePropagation()
}

function onServerFormDirty(event) {
  const detail = event.detail || {}
  if (!detail.form) return
  const form = document.getElementById(detail.form)
  if (!form) return
  if (form.hasAttribute("data-no-warn")) return
  if (detail.dirty === false) {
    serverForcedDirty.delete(form)
  } else {
    serverForcedDirty.add(form)
  }
}

function init() {
  scanDocument()

  new MutationObserver(() => {
    scanDocument()
    pruneDetachedForms()
  }).observe(document.body, {childList: true, subtree: true})

  window.addEventListener("beforeunload", onBeforeUnload)
  document.addEventListener("click", onCapturedClick, true)
  window.addEventListener("phx:form-dirty", onServerFormDirty)
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init, {once: true})
} else {
  init()
}
