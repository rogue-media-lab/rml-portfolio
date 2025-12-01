import { Controller } from "@hotwired/stimulus"

/**
 * Repeat Mode Controller
 *
 * Manages repeat modes with 3 states:
 * - 'off': Playback stops after current song ends
 * - 'all': Queue loops continuously (like auto-advance)
 * - 'one': Current song repeats indefinitely
 *
 * Follows standard music player convention (Spotify/Apple Music)
 */
export default class extends Controller {
  static targets = ["icon", "badge"]

  static values = {
    mode: { type: String, default: "off" } // 'off', 'all', 'one'
  }

  connect() {
    // Load from localStorage (migrate old autoAdvance setting)
    const savedMode = localStorage.getItem("playerRepeat")

    // Migration: if no repeat mode saved, check old auto-advance setting
    if (!savedMode) {
      const oldAutoAdvance = localStorage.getItem("playerAutoAdvance") === "true"
      this.modeValue = oldAutoAdvance ? "all" : "off"
      localStorage.setItem("playerRepeat", this.modeValue)
    } else {
      this.modeValue = savedMode
    }

    this.updateUI()
    this.dispatchState()
  }

  /**
   * Cycle through repeat modes: off → all → one → off
   */
  toggle() {
    const modes = ['off', 'all', 'one']
    const currentIndex = modes.indexOf(this.modeValue)
    const nextIndex = (currentIndex + 1) % modes.length

    this.modeValue = modes[nextIndex]
    localStorage.setItem("playerRepeat", this.modeValue)

    console.log("🔁 Repeat mode changed to:", this.modeValue)
    this.updateUI()
    this.dispatchState()
  }

  /**
   * Update UI based on current mode
   */
  updateUI() {
    const icon = this.iconTarget
    const badge = this.badgeTarget

    switch (this.modeValue) {
      case 'off':
        // Gray, no badge
        icon.classList.remove('text-green-400')
        icon.classList.add('text-gray-400')
        badge.classList.add('hidden')
        this.element.setAttribute('aria-label', 'Repeat: Off')
        break

      case 'all':
        // Green, no badge
        icon.classList.remove('text-gray-400')
        icon.classList.add('text-green-400')
        badge.classList.add('hidden')
        this.element.setAttribute('aria-label', 'Repeat: All')
        break

      case 'one':
        // Green with "1" badge
        icon.classList.remove('text-gray-400')
        icon.classList.add('text-green-400')
        badge.classList.remove('hidden')
        this.element.setAttribute('aria-label', 'Repeat: One')
        break
    }
  }

  /**
   * Dispatch event to player controller
   */
  dispatchState() {
    document.dispatchEvent(new CustomEvent("player:repeat:changed", {
      detail: { mode: this.modeValue }
    }))
  }

  /**
   * Handle value changes (if set externally)
   */
  modeValueChanged() {
    this.updateUI()
  }
}
