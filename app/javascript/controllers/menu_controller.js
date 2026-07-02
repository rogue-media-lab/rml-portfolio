import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  toggle() {
    this.panelTarget.classList.toggle("hidden")
  }

  // Close when clicking outside
  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.panelTarget.classList.add("hidden")
    }
  }

  connect() {
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.boundClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }
}