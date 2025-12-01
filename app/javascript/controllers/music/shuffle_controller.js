import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = ["active", "inactive"]
  static values = {
    active: { type: Boolean, default: false }
  }

  connect() {
    // Load from localStorage
    const savedState = localStorage.getItem("playerShuffle") === "true"
    this.activeValue = savedState
    this.updateClass()

    // Initialize player state
    this.dispatchState()
  }

  toggle() {
    this.activeValue = !this.activeValue
    localStorage.setItem("playerShuffle", this.activeValue)
    this.dispatchState()
  }

  dispatchState() {
    document.dispatchEvent(new CustomEvent("player:shuffle:changed", {
      detail: { enabled: this.activeValue }
    }))
  }

  activeValueChanged() {
    this.updateClass()
    this.dispatchState()
  }

  updateClass() {
    this.element.classList.toggle(this.activeClass, this.activeValue)
    this.element.classList.toggle(this.inactiveClass, !this.activeValue)
  }
}
