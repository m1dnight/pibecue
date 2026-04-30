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

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

function polarToCartesian(cx, cy, r, angleDeg) {
  const a = angleDeg * Math.PI / 180
  return [cx + r * Math.sin(a), cy - r * Math.cos(a)]
}

function describeArc(cx, cy, r, startAngle, endAngle) {
  const [sx, sy] = polarToCartesian(cx, cy, r, startAngle)
  const [ex, ey] = polarToCartesian(cx, cy, r, endAngle)
  let sweep = endAngle - startAngle
  if (sweep < 0) sweep += 360
  const largeArc = sweep > 180 ? 1 : 0
  return `M ${sx} ${sy} A ${r} ${r} 0 ${largeArc} 1 ${ex} ${ey}`
}

const Hooks = {}

Hooks.TempDial = {
  mounted() {
    const svg = this.el.querySelector('svg')
    const display = this.el.querySelector('[data-dial-value]')
    const fillPath = this.el.querySelector('[data-dial-fill]')
    const thumb = this.el.querySelector('[data-dial-thumb]')
    const min = +this.el.dataset.min
    const max = +this.el.dataset.max
    const cx = 150, cy = 150, r = 120
    const startAngle = 225
    const sweep = 270

    let value = Math.max(min, Math.min(max, +this.el.dataset.value))
    let dragging = false

    const draw = (v) => {
      const pct = (v - min) / (max - min)
      const angle = startAngle + pct * sweep
      fillPath.setAttribute('d', describeArc(cx, cy, r, startAngle, angle))
      const [tx, ty] = polarToCartesian(cx, cy, r, angle)
      thumb.setAttribute('cx', tx)
      thumb.setAttribute('cy', ty)
      display.textContent = Math.round(v) + '°C'
    }

    const angleFromPoint = (clientX, clientY) => {
      const rect = svg.getBoundingClientRect()
      const px = clientX - (rect.left + rect.width / 2)
      const py = clientY - (rect.top + rect.height / 2)
      let a = Math.atan2(px, -py) * 180 / Math.PI
      if (a < 0) a += 360
      return a
    }

    const valueFromAngle = (a) => {
      let rel = (a - startAngle + 360) % 360
      if (rel <= sweep) return min + (rel / sweep) * (max - min)
      return rel < (sweep + 360) / 2 ? max : min
    }

    const handle = (e) => {
      const point = e.touches ? e.touches[0] : e
      value = Math.round(valueFromAngle(angleFromPoint(point.clientX, point.clientY)))
      value = Math.max(min, Math.min(max, value))
      draw(value)
    }

    const start = (e) => { dragging = true; handle(e); e.preventDefault() }
    const move  = (e) => { if (dragging) { handle(e); e.preventDefault() } }
    const end   = (e) => {
      if (!dragging) return
      dragging = false
      this.pushEvent('dial-changed', { value })
    }

    svg.addEventListener('mousedown', start)
    svg.addEventListener('touchstart', start, { passive: false })
    window.addEventListener('mousemove', move)
    window.addEventListener('touchmove', move, { passive: false })
    window.addEventListener('mouseup', end)
    window.addEventListener('touchend', end)

    this._handlers = { move, end }
    draw(value)
  },

  destroyed() {
    if (!this._handlers) return
    window.removeEventListener('mousemove', this._handlers.move)
    window.removeEventListener('touchmove', this._handlers.move)
    window.removeEventListener('mouseup',   this._handlers.end)
    window.removeEventListener('touchend',  this._handlers.end)
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let timezone = Intl.DateTimeFormat().resolvedOptions().timeZone
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: Hooks,
  params: {_csrf_token: csrfToken, timezone: timezone}
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

