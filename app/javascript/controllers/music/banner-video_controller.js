import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["thumb"]
  static classes = ["active", "inactive"]

  connect() {
    console.log("Banner video controller connected")
    // Load preference from localStorage (default to false - show image)
    const preference = localStorage.getItem("bannerVideoEnabled")
    const isEnabled = preference === "true"

    this.updateToggleState(isEnabled)

    // Dispatch initial state to banner controller
    this.dispatchVideoPreferenceEvent(isEnabled)
  }

  toggle(event) {
    event.preventDefault()
    const currentState = this.element.classList.contains(this.activeClass)
    const newState = !currentState

    this.updateToggleState(newState)
    localStorage.setItem("bannerVideoEnabled", newState)

    // Notify banner controller of preference change
    this.dispatchVideoPreferenceEvent(newState)
  }

  updateToggleState(isEnabled) {
    if (isEnabled) {
      this.element.classList.remove(this.inactiveClass)
      this.element.classList.add(this.activeClass)
    } else {
      this.element.classList.remove(this.activeClass)
      this.element.classList.add(this.inactiveClass)
    }
  }

  dispatchVideoPreferenceEvent(enabled) {
    const event = new CustomEvent("music:banner:video-preference", {
      detail: { enabled },
      bubbles: true
    })
    window.dispatchEvent(event)
  }
}
