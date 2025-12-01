import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { songs: String }

  initialize() {
    this.songsArray = []
  }

  connect() {
    try {
      // Parse JSON and validate
      const parsed = JSON.parse(this.songsValue)

      // Ensure we have an array
      if (!Array.isArray(parsed)) {
        throw new Error("Parsed data is not an array")
      }

      // Filter valid songs
      this.songsArray = parsed.filter(song =>
        song?.id && song?.url && song?.title
      )

      this.updatePlayerQueue() // Initial update

      // Request player to broadcast current state for new song cards
      setTimeout(() => {
        window.dispatchEvent(new CustomEvent("player:sync-request"))
      }, 100)

    } catch (error) {
      console.error("Song list initialization failed:", error)
      this.songsArray = [] // Fallback to empty array
    }
  }

  setupEventListeners() {
    
    // Update queue when any song is played
    document.addEventListener("player:play-requested", () => {
      this.updatePlayerQueue()
    })
  }

  updatePlayerQueue() {
    // Double-check array before sending
    if (!Array.isArray(this.songsArray)) {
      console.error("Invalid songsArray - resetting")
      this.songsArray = []
    }
    document.dispatchEvent(new CustomEvent("player:queue:updated", {
      detail: { queue: [...this.songsArray] } // Spread operator clones array
    }))
  }
}
