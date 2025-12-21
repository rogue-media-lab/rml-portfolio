import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { songs: String }

  initialize() {
    this.songsArray = []
  }

  connect() {
    console.log("🎵 SONG-LIST: Controller connected")

    try {
      console.log("🎵 SONG-LIST: Raw songsValue:", this.songsValue?.substring(0, 100) + "...")

      // Parse JSON and validate
      const parsed = JSON.parse(this.songsValue)
      console.log("🎵 SONG-LIST: Parsed songs:", parsed?.length || 0)

      // Ensure we have an array
      if (!Array.isArray(parsed)) {
        throw new Error("Parsed data is not an array")
      }

      // Filter valid songs
      this.songsArray = parsed.filter(song =>
        song?.id && song?.url && song?.title
      )

      console.log("🎵 SONG-LIST: Filtered songs array:", this.songsArray.length)
      console.log("🎵 SONG-LIST: First song:", this.songsArray[0]?.title || "none")

      this.setupEventListeners() // Set up event listeners BEFORE initial update
      this.updatePlayerQueue() // Initial update

      // Request player to broadcast current state for new song cards
      setTimeout(() => {
        window.dispatchEvent(new CustomEvent("player:sync-request"))
      }, 100)

    } catch (error) {
      console.error("🎵 SONG-LIST: Initialization failed:", error)
      console.error("🎵 SONG-LIST: Error details:", error.message, error.stack)
      this.songsArray = [] // Fallback to empty array
    }
  }

  setupEventListeners() {
    console.log("🎵 SONG-LIST: Setting up event listeners")

    // Respond to queue requests from player (critical for Service Worker reloads)
    document.addEventListener("player:queue:request", () => {
      console.log("🎵 SONG-LIST: player:queue:request received, sending queue")
      this.updatePlayerQueue()
    })
  }

  updatePlayerQueue() {
    // Double-check array before sending
    if (!Array.isArray(this.songsArray)) {
      console.error("Invalid songsArray - resetting")
      this.songsArray = []
    }

    console.log("🎵 QUEUE UPDATE: Updating player queue with", this.songsArray.length, "songs")
    console.log("🎵 QUEUE UPDATE: First song:", this.songsArray[0]?.title || "none")
    console.log("🎵 QUEUE UPDATE: Last song:", this.songsArray[this.songsArray.length - 1]?.title || "none")

    document.dispatchEvent(new CustomEvent("player:queue:updated", {
      detail: { queue: [...this.songsArray] } // Spread operator clones array
    }))
  }
}
