import { Controller } from "@hotwired/stimulus"

// Toast-style flash controller
// Slides in from the right, auto-dismisses after 3s, slides out
export default class extends Controller {
  static values = { timeout: { type: Number, default: 3000 } }

  connect() {
    // Slide in
    requestAnimationFrame(() => {
      this.element.style.transform = "translateX(0)"
      this.element.style.opacity = "1"
    })

    // Auto-dismiss
    this.timeout = setTimeout(() => this.dismiss(), this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.style.transform = "translateX(120%)"
    this.element.style.opacity = "0"
    setTimeout(() => this.element.remove(), 300)
  }
}
