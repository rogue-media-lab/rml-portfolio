import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "trigger"]
  static values = {
    open: { type: Boolean, default: false }
  }

  connect() {
    console.log("Settings menu controller connected")
    // Close menu when clicking outside
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
    this.closeOnEscape = this.closeOnEscape.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
    document.removeEventListener("keydown", this.closeOnEscape)
  }

  toggleMenu(event) {
    event.stopPropagation()
    this.openValue = !this.openValue
  }

  openValueChanged() {
    if (this.openValue) {
      this.showMenu()
    } else {
      this.hideMenu()
    }
  }

  showMenu() {
    this.menuTarget.classList.remove("hidden")
    // Add listeners after a short delay to prevent immediate closing
    setTimeout(() => {
      document.addEventListener("click", this.closeOnOutsideClick)
      document.addEventListener("keydown", this.closeOnEscape)
    }, 10)
  }

  hideMenu() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.closeOnOutsideClick)
    document.removeEventListener("keydown", this.closeOnEscape)
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.openValue = false
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.openValue = false
    }
  }

  // Prevent menu from closing when clicking inside it
  preventClose(event) {
    // Don't stop propagation for links - let Turbo handle them
    if (event.target.tagName === 'A' || event.target.closest('a')) {
      return
    }
    event.stopPropagation()
  }
}
