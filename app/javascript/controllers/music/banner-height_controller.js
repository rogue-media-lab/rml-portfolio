import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["banner", "arrow"]
  static values = {
    expanded: { type: Boolean, default: false }
  }

  connect() {
    console.log("Banner height controller connected")
    // Load saved preference from localStorage
    const savedState = localStorage.getItem("bannerExpanded")
    if (savedState !== null) {
      this.expandedValue = savedState === "true"
    }
    // Dispatch initial state after a short delay to ensure other controllers are connected
    setTimeout(() => {
      this.dispatchHeightChangeEvent(this.expandedValue)
    }, 100)
  }

  toggle(event) {
    event.preventDefault()
    this.expandedValue = !this.expandedValue
  }

  expandedValueChanged() {
    if (this.expandedValue) {
      this.expand()
    } else {
      this.collapse()
    }
    // Save preference to localStorage
    localStorage.setItem("bannerExpanded", this.expandedValue)
  }

  expand() {
    // Set banner to full screen height
    this.bannerTarget.style.height = "100vh"
    // Rotate arrow to point up
    this.arrowTarget.style.transform = "rotate(180deg)"
    // Dispatch event for other controllers to respond
    this.dispatchHeightChangeEvent(true)
  }

  collapse() {
    // Set banner to default 275px height
    this.bannerTarget.style.height = "275px"
    // Reset arrow to point down
    this.arrowTarget.style.transform = "rotate(0deg)"
    // Dispatch event for other controllers to respond
    this.dispatchHeightChangeEvent(false)
  }

  dispatchHeightChangeEvent(expanded) {
    window.dispatchEvent(new CustomEvent("music:banner:height-changed", {
      detail: { expanded: expanded }
    }))
  }
}
