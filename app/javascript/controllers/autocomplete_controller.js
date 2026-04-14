import { Controller } from "@hotwired/stimulus"

/**
 * Provides address autocomplete by fetching suggestions from the /autocomplete endpoint.
 *
 * When a user selects a suggestion, lat/lon/postal_code are passed as hidden fields
 * so the server can skip re-geocoding the display name. When the user edits the input
 * (types instead of selecting), the hidden fields are cleared to force server-side geocoding.
 *
 * Keyboard navigation: ArrowDown/Up to highlight, Enter to select, Escape to dismiss.
 * Debounces input by 300ms to avoid excessive API calls while typing.
 *
 * Targets:
 *   input — the text input field
 *   list  — the <ul> dropdown container for suggestions
 *
 * Values:
 *   url — the autocomplete endpoint (e.g. "/autocomplete")
 */
export default class extends Controller {
  static targets = ["input", "list"]
  static values = { url: String }

  connect() {
    this.selectedIndex = -1
    this.timeout = null
    this.suggestions = []
    this._clickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this._clickOutside)
  }

  disconnect() {
    clearTimeout(this.timeout)
    document.removeEventListener("click", this._clickOutside)
  }

  /** Debounces input and triggers a search after 300ms of inactivity. */
  onInput() {
    clearTimeout(this.timeout)
    this.clearHiddenFields()
    const query = this.inputTarget.value.trim()

    if (query.length < 3) {
      this.hideList()
      return
    }

    this.timeout = setTimeout(() => this.search(query), 300)
  }

  /** Fetches suggestions from the autocomplete endpoint and displays them. */
  async search(query) {
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`)
      if (!response.ok) { this.hideList(); return }
      this.suggestions = await response.json()
      this.showSuggestions(this.suggestions)
    } catch {
      this.hideList()
    }
  }

  /** Renders the suggestion list items, or hides the list if empty. */
  showSuggestions(suggestions) {
    if (suggestions.length === 0) {
      this.hideList()
      return
    }

    this.selectedIndex = -1
    this.listTarget.innerHTML = suggestions.map((s, i) =>
      `<li data-index="${i}"
           class="px-4 py-2.5 cursor-pointer text-white text-sm font-light border-b border-gray-700 last:border-0 transition-colors hover:bg-gray-800"
           role="option">
        ${this.escapeHtml(s.display_name)}
      </li>`
    ).join("")
    this.listTarget.classList.remove("hidden")
  }

  /**
   * Handles click on a suggestion item.
   * Sets the input value, populates hidden coordinate fields, hides the dropdown,
   * and auto-submits the form.
   */
  select(event) {
    const li = event.target.closest("li")
    if (!li) return
    const index = parseInt(li.dataset.index, 10)
    const suggestion = this.suggestions[index]
    if (!suggestion) return

    this.inputTarget.value = suggestion.display_name
    this.setHiddenFields(suggestion)
    this.hideList()
    this.inputTarget.closest("form").requestSubmit()
  }

  /** Handles keyboard navigation within the dropdown. */
  onKeydown(event) {
    if (!this.hasListTarget || this.listTarget.classList.contains("hidden")) return

    const items = this.listTarget.querySelectorAll("li")
    if (items.length === 0) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
        this.highlightItem(items)
        break
      case "ArrowUp":
        event.preventDefault()
        this.selectedIndex = Math.max(this.selectedIndex - 1, -1)
        this.highlightItem(items)
        break
      case "Enter":
        if (this.selectedIndex >= 0) {
          event.preventDefault()
          items[this.selectedIndex].click()
        }
        break
      case "Escape":
        this.hideList()
        break
    }
  }

  /** Applies visual highlight to the currently selected item. */
  highlightItem(items) {
    items.forEach((item, i) => {
      if (i === this.selectedIndex) {
        item.classList.add("bg-gray-800")
      } else {
        item.classList.remove("bg-gray-800")
      }
    })
  }

  /** Hides the dropdown and resets the selection index. */
  hideList() {
    if (this.hasListTarget) {
      this.listTarget.classList.add("hidden")
      this.listTarget.innerHTML = ""
    }
    this.selectedIndex = -1
  }

  /**
   * Populates hidden form fields with coordinates from the selected suggestion.
   * This lets the server skip re-geocoding on form submit.
   */
  setHiddenFields(suggestion) {
    const form = this.inputTarget.closest("form")
    if (!form) return

    this.ensureHiddenField(form, "lat", suggestion.lat)
    this.ensureHiddenField(form, "lon", suggestion.lon)
    this.ensureHiddenField(form, "postal_code", suggestion.postal_code || "")
  }

  /**
   * Clears hidden coordinate fields when the user edits the input.
   * This ensures manually typed addresses go through server-side geocoding.
   */
  clearHiddenFields() {
    const form = this.inputTarget.closest("form")
    if (!form) return

    for (const name of ["lat", "lon", "postal_code"]) {
      const field = form.querySelector(`input[name="${name}"]`)
      if (field) field.remove()
    }
  }

  /** Creates or updates a hidden input field within the form. */
  ensureHiddenField(form, name, value) {
    let field = form.querySelector(`input[name="${name}"]`)
    if (!field) {
      field = document.createElement("input")
      field.type = "hidden"
      field.name = name
      form.appendChild(field)
    }
    field.value = value
  }

  /** Closes the dropdown when clicking outside the autocomplete container. */
  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideList()
    }
  }

  /** Escapes HTML entities to prevent XSS in suggestion display names. */
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
