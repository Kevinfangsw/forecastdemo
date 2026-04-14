import { Controller } from "@hotwired/stimulus"

/**
 * Toggles all temperature displays between °F and °C, and wind between mph and km/h.
 * Persists the user's preference in localStorage so it survives page reloads.
 *
 * How it works:
 *   - Server renders temperatures in Fahrenheit and stores the raw value in data-temp-f.
 *   - Server renders wind speed in mph and stores the raw value in data-wind-mph.
 *   - On connect (or toggle), this controller reads the raw values and either
 *     displays them as-is (°F) or converts them client-side (°C / km/h).
 *   - No server round-trip is needed for unit switching.
 *
 * Targets:
 *   temp     — any element with data-temp-f (temperature in Fahrenheit)
 *   wind     — any element with data-wind-mph (wind speed in mph)
 *   windUnit — the unit label element (displays "mph" or "km/h")
 *   btnF     — the °F toggle button
 *   btnC     — the °C toggle button
 */
export default class extends Controller {
  static targets = ["temp", "wind", "windUnit", "btnF", "btnC"]

  connect() {
    this.unit = localStorage.getItem("weatherUnit") || "F"
    this.apply()
  }

  /** Switches to the unit specified by the clicked button's data-unit-toggle-unit-param. */
  toggle(event) {
    this.unit = event.params.unit
    localStorage.setItem("weatherUnit", this.unit)
    this.apply()
  }

  /** Converts all temperature and wind values and updates button styling. */
  apply() {
    const isMetric = this.unit === "C"

    // Convert temperatures: °F → °C = (°F - 32) × 5/9
    this.tempTargets.forEach(el => {
      const f = parseFloat(el.dataset.tempF)
      if (isNaN(f)) return
      el.textContent = isMetric ? Math.round((f - 32) * 5 / 9) : Math.round(f)
    })

    // Convert wind: mph → km/h = mph × 1.60934
    this.windTargets.forEach(el => {
      const mph = parseFloat(el.dataset.windMph)
      if (isNaN(mph)) return
      el.textContent = isMetric ? (mph * 1.60934).toFixed(1) : mph
    })

    // Update the wind unit label
    this.windUnitTargets.forEach(el => {
      el.textContent = isMetric ? "km/h" : "mph"
    })

    // Toggle active/inactive button styling
    if (this.hasBtnFTarget && this.hasBtnCTarget) {
      this.btnFTarget.classList.toggle("bg-white/25", !isMetric)
      this.btnFTarget.classList.toggle("text-white", !isMetric)
      this.btnFTarget.classList.toggle("bg-transparent", isMetric)
      this.btnFTarget.classList.toggle("text-white/50", isMetric)
      this.btnCTarget.classList.toggle("bg-white/25", isMetric)
      this.btnCTarget.classList.toggle("text-white", isMetric)
      this.btnCTarget.classList.toggle("bg-transparent", !isMetric)
      this.btnCTarget.classList.toggle("text-white/50", !isMetric)
    }
  }
}
