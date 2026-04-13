// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.
import "../css/app.css"

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/holter"
import topbar from "../vendor/topbar"

function getOrCreateSessionId() {
  let sessionId = sessionStorage.getItem("session_id")
  if (!sessionId) {
    sessionId = typeof crypto !== 'undefined' && crypto.randomUUID 
      ? crypto.randomUUID() 
      : Math.random().toString(36).substring(2) + Date.now().toString(36)
    sessionStorage.setItem("session_id", sessionId)
  }
  return sessionId
}

const SESSION_ID = getOrCreateSessionId()

// --- Client-Side Telemetry ---
function sendLogToBackend(level, message, stack = null) {
  const body = JSON.stringify({
    level,
    message: typeof message === 'string' ? message : JSON.stringify(message),
    stack,
    url: window.location.href
  })

  // Use fetch with keepalive to ensure log is sent even if page is closing
  fetch("/api/v1/telemetry/logs", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-session-id": SESSION_ID
    },
    body,
    keepalive: true
  }).catch(() => {}) // Silently fail to avoid infinite recursion
}

// Intercept global errors
window.onerror = (message, source, lineno, colno, error) => {
  sendLogToBackend("error", message, error?.stack || `${source}:${lineno}:${colno}`)
}

window.onunhandledrejection = (event) => {
  sendLogToBackend("error", `Unhandled Rejection: ${event.reason}`)
}

// Intercept console methods (keeping original functionality)
const originalConsole = {
  log: console.log,
  warn: console.warn,
  error: console.error
}

console.log = (...args) => {
  originalConsole.log(...args)
  if (process.env.NODE_ENV === "production") sendLogToBackend("info", args.join(" "))
}

console.warn = (...args) => {
  originalConsole.warn(...args)
  sendLogToBackend("warn", args.join(" "))
}

console.error = (...args) => {
  originalConsole.error(...args)
  sendLogToBackend("error", args.join(" "))
}
// --- End Telemetry ---

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken, session_id: SESSION_ID},
  hooks: {...colocatedHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

