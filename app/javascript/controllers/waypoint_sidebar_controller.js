import { Controller } from "@hotwired/stimulus"

// Toggles the channel sidebar on mobile (hamburger button).
export default class extends Controller {
  static targets = ["sidebar", "overlay"]

  connect() {
    this.close()
  }

  toggle() {
    if (this.sidebarTarget.classList.contains("translate-x-0")) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.sidebarTarget.classList.remove("-translate-x-full")
    this.sidebarTarget.classList.add("translate-x-0")
    this.overlayTarget.classList.remove("hidden")
  }

  close() {
    this.sidebarTarget.classList.add("-translate-x-full")
    this.sidebarTarget.classList.remove("translate-x-0")
    this.overlayTarget.classList.add("hidden")
  }
}