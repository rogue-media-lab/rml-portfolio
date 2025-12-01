// app/javascript/controllers/music/search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "clearButton", "hint"]
  static values = {
    debounceDelay: { type: Number, default: 400 } // 400ms delay
  }

  connect() {
    this.debounceTimer = null
    console.log("Search controller connected")

    // Show clear button if input has value on connect
    if (this.inputTarget.value.trim().length > 0) {
      this.clearButtonTarget.classList.remove("hidden")
    }
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  performSearch() {
    const query = this.inputTarget.value.trim()

    // Show/hide clear button
    if (query.length > 0) {
      this.clearButtonTarget.classList.remove("hidden")
    } else {
      this.clearButtonTarget.classList.add("hidden")
    }

    // Show hint if query is too short
    if (query.length > 0 && query.length < 3) {
      this.showHint()
      return
    } else {
      this.hideHint()
    }

    // Clear existing timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    // Debounce the search
    this.debounceTimer = setTimeout(() => {
      this.executeSearch(query)
    }, this.debounceDelayValue)
  }

  executeSearch(query) {
    console.log("Executing search for:", query)

    // If query is empty or less than 3 chars, load default songs view
    if (query.length < 3) {
      this.loadDefaultView()
      return
    }

    // Construct search URL
    const searchUrl = `/zuke/search?q=${encodeURIComponent(query)}`

    // Use Turbo to load search results into the music-frame
    fetch(searchUrl, {
      headers: {
        "Accept": "text/vnd.turbo-stream.html, text/html"
      }
    })
    .then(response => response.text())
    .then(html => {
      // Update the turbo frame with search results
      const frame = document.getElementById("music-frame")
      if (frame) {
        frame.innerHTML = html
      }
    })
    .catch(error => {
      console.error("Search error:", error)
    })
  }

  loadDefaultView() {
    // Load the default songs view when clearing search
    const songsUrl = "/zuke/songs"

    fetch(songsUrl, {
      headers: {
        "Accept": "text/vnd.turbo-stream.html, text/html"
      }
    })
    .then(response => response.text())
    .then(html => {
      const frame = document.getElementById("music-frame")
      if (frame) {
        frame.innerHTML = html
      }
    })
    .catch(error => {
      console.error("Error loading default view:", error)
    })
  }

  clearSearch() {
    this.inputTarget.value = ""
    this.clearButtonTarget.classList.add("hidden")
    this.hideHint()
    this.loadDefaultView()
    this.inputTarget.focus()
  }

  showHint() {
    if (this.hasHintTarget) {
      this.hintTarget.classList.remove("hidden")
    }
  }

  hideHint() {
    if (this.hasHintTarget) {
      this.hintTarget.classList.add("hidden")
    }
  }
}
