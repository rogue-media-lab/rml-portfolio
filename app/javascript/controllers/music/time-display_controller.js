import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["current", "duration"]

  connect() {
    document.addEventListener("player:time:update", this.updateDisplay.bind(this))
  }

  updateDisplay(event) {
    const { current, duration } = event.detail

    // Update all current time displays (if multiple exist)
    this.currentTargets.forEach(target => {
      target.textContent = this.formatTime(current)
    })

    // Update all duration displays (mobile and desktop)
    this.durationTargets.forEach(target => {
      target.textContent = `-${this.formatTime(duration - current)}`
    })
  }

  formatTime(seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60).toString().padStart(2, "0")
    return `${mins}:${secs}`
  }
}
