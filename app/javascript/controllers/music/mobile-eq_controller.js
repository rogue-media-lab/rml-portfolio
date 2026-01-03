import { Controller } from "@hotwired/stimulus"

/**
 * Mobile EQ Toggle Controller
 *
 * Manages the localStorage setting for enabling/disabling EQ on mobile devices.
 * When enabled: User gets EQ functionality but loses background playback
 * When disabled: User gets background playback but no EQ
 */
export default class extends Controller {
  static targets = ["thumb"]
  static classes = ["active", "inactive"]

  connect() {
    console.log("Mobile EQ toggle connected")

    // Only show this toggle on mobile devices
    if (!this.isMobile()) {
      this.element.closest('.flex.items-center')?.classList.add('hidden')
      return
    }

    // Load saved state from localStorage (default: false/disabled)
    const enabled = localStorage.getItem("mobileEQEnabled") === "true"
    this.updateUI(enabled)
  }

  /**
   * Detect mobile device (same logic as player and equalizer)
   */
  isMobile() {
    const mobileUA = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
    const isTouchDevice = ('ontouchstart' in window) &&
                          (navigator.maxTouchPoints > 0) &&
                          !window.matchMedia("(pointer: fine)").matches
    const isSmallScreen = window.innerWidth <= 768
    return (mobileUA || isTouchDevice) && isSmallScreen
  }

  /**
   * Toggle the setting
   */
  toggle() {
    const currentState = localStorage.getItem("mobileEQEnabled") === "true"
    const newState = !currentState

    // Save to localStorage
    localStorage.setItem("mobileEQEnabled", newState.toString())
    console.log("Mobile EQ toggled:", newState)

    // Update UI
    this.updateUI(newState)

    // Dispatch event so other controllers know the setting changed
    document.dispatchEvent(new CustomEvent("mobile-eq:toggled", {
      detail: { enabled: newState }
    }))

    // Show warning message
    this.showWarning(newState)
  }

  /**
   * Update toggle button UI
   */
  updateUI(enabled) {
    if (enabled) {
      this.element.classList.remove(this.inactiveClass)
      this.element.classList.add(this.activeClass)
      this.element.setAttribute("aria-checked", "true")
    } else {
      this.element.classList.remove(this.activeClass)
      this.element.classList.add(this.inactiveClass)
      this.element.setAttribute("aria-checked", "false")
    }
  }

  /**
   * Show warning message when toggling
   */
  showWarning(enabled) {
    const message = enabled
      ? "EQ enabled! Background playback will stop when screen locks. Reload the page for this change to take effect."
      : "EQ disabled! Background playback restored. Reload the page for this change to take effect."

    // Dispatch event for a toast notification (if you have one)
    // Or just use alert for now
    if (confirm(message + "\n\nReload now?")) {
      window.location.reload()
    }
  }
}
