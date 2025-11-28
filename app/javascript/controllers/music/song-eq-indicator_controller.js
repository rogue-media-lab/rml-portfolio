// app/javascript/controllers/music/song-eq-indicator_controller.js
import { Controller } from "@hotwired/stimulus"

/**
 * Song EQ Indicator Controller
 *
 * Shows/hides the EQ icon on song cards based on whether
 * custom EQ settings exist for that song in localStorage.
 */
export default class extends Controller {
  static targets = ["indicator"]
  static values = {
    songUrl: String
  }

  connect() {
    // Check if this song has custom EQ settings
    this.updateIndicator()

    // Listen for EQ save/remove events
    document.addEventListener("equalizer:saved", this.handleEQChange.bind(this))
    document.addEventListener("equalizer:removed", this.handleEQChange.bind(this))
  }

  disconnect() {
    document.removeEventListener("equalizer:saved", this.handleEQChange.bind(this))
    document.removeEventListener("equalizer:removed", this.handleEQChange.bind(this))
  }

  /**
   * Handle EQ settings changes
   */
  handleEQChange(event) {
    // Only update if this is the song that was changed
    if (event.detail.url === this.songUrlValue) {
      this.updateIndicator()
    }
  }

  /**
   * Update indicator visibility based on localStorage
   */
  updateIndicator() {
    if (!this.hasIndicatorTarget || !this.songUrlValue) {
      console.log("EQ Indicator: Missing target or URL", {
        hasTarget: this.hasIndicatorTarget,
        url: this.songUrlValue
      })
      return
    }

    const settings = this.getEQSettings()
    const hasSavedEQ = !!settings[this.songUrlValue]

    console.log("EQ Indicator: Checking song", {
      songUrl: this.songUrlValue,
      hasSavedEQ: hasSavedEQ,
      allSettings: Object.keys(settings)
    })

    if (hasSavedEQ) {
      console.log("EQ Indicator: Showing indicator for", this.songUrlValue)
      this.indicatorTarget.classList.remove("hidden")
    } else {
      this.indicatorTarget.classList.add("hidden")
    }
  }

  /**
   * Get EQ settings from localStorage
   */
  getEQSettings() {
    try {
      const json = localStorage.getItem("zuke_eq_settings")
      return json ? JSON.parse(json) : {}
    } catch (error) {
      console.error("EQ Indicator: Error reading settings:", error)
      return {}
    }
  }
}
