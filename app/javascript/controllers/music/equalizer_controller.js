// app/javascript/controllers/music/equalizer_controller.js
import { Controller } from "@hotwired/stimulus"

/**
 * Equalizer Controller
 *
 * Manages a 10-band graphic equalizer using Web Audio API BiquadFilterNodes.
 * Features:
 * - 10 frequency bands (32Hz to 16kHz)
 * - Preset configurations (Rock, Bass Boost, etc.)
 * - Per-song EQ settings stored in localStorage
 * - Integration with WaveSurfer player
 */
export default class extends Controller {
  static targets = [
    "panel",
    "trigger",
    "triggerIcon",
    "saveButton",
    "songIndicator",
    "unavailableMessage",
    "headerContent",
    "mainContent",
    ...Array.from({ length: 10 }, (_, i) => `band${i}`),
    ...Array.from({ length: 10 }, (_, i) => `gainDisplay${i}`)
  ]

  // Standard 10-band EQ frequencies
  frequencies = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

  // EQ Presets (gain values in dB for each band)
  presets = {
    "flat": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    "rock": [5, 4, 3, 1, -1, -1, 0, 2, 3, 4],
    "pop": [0, 2, 4, 4, 2, 0, -1, -1, 0, 1],
    "jazz": [3, 2, 1, 1, -1, -1, 0, 1, 2, 3],
    "classical": [4, 3, 2, 0, -1, -1, 0, 2, 3, 4],
    "electronic": [4, 3, 1, 0, -2, 2, 1, 2, 3, 4],
    "bass-boost": [8, 6, 4, 2, 0, 0, 0, 0, 0, 0],
    "treble-boost": [0, 0, 0, 0, 0, 2, 4, 6, 8, 8]
  }

  // Audio nodes
  filterNodes = []
  audioContext = null
  sourceNode = null
  isConnected = false

  // Current state
  currentSongUrl = null
  currentGains = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  
  // URL to match (stripped of query params)
  matchSongUrl = null

  connect() {
    // Check for mobile first
    if (this.isMobile()) {
      console.log("EQ: Mobile device detected - disabling Equalizer to preserve background playback")

      if (this.hasUnavailableMessageTarget) {
        this.unavailableMessageTarget.textContent = "Equalizer is disabled on mobile devices. iOS requires native HTML5 audio for background playback and lock screen controls. The Web Audio API (required for EQ) conflicts with these features."
        this.unavailableMessageTarget.classList.remove("hidden")
      }

      if (this.hasHeaderContentTarget) this.headerContentTarget.classList.add("hidden")
      if (this.hasMainContentTarget) this.mainContentTarget.classList.add("hidden")

      // Stop here - do not attach listeners or hook into audio
      return
    }

    console.log("EQ: Desktop device - enabling Equalizer")

    // Listen for player events
    window.addEventListener("audio:changed", this.handleSongChange.bind(this))
    window.addEventListener("player:state:changed", this.handlePlayerState.bind(this))
    window.addEventListener("audio:ready", this.handleAudioReady.bind(this))

    // Try to hook into WaveSurfer initialization
    this.setupWaveSurferIntegration()

    // Initialize as disabled until audio is ready
    this.updateSaveButtonState()
  }

  /**
   * Detect mobile device
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
   * Setup integration with WaveSurfer before it initializes audio
   */
  setupWaveSurferIntegration() {
    // Get player controller
    const playerElement = document.querySelector('[data-controller*="music--player"]')
    if (!playerElement) {
      console.log("EQ: Player not ready yet, will try on audio:ready")
      return
    }

    const playerController = this.application.getControllerForElementAndIdentifier(
      playerElement,
      "music--player"
    )

    if (!playerController) {
      console.log("EQ: Player controller not ready")
      return
    }

    // Monitor for when WaveSurfer gets created
    this.checkForWaveSurfer(playerController)
  }

  /**
   * Check if WaveSurfer is ready and hook into it
   */
  checkForWaveSurfer(playerController) {
    if (playerController.wavesurfer) {
      console.log("EQ: WaveSurfer already exists, setting up filters")
      this.hookIntoWaveSurfer(playerController.wavesurfer)
    } else {
      // WaveSurfer not created yet, will try on audio:ready
      console.log("EQ: WaveSurfer not created yet")
    }
  }

  /**
   * Hook into WaveSurfer's audio graph
   */
  hookIntoWaveSurfer(wavesurfer) {
    console.log("EQ: Hooking into WaveSurfer:", wavesurfer)

    // Store reference
    this.wavesurfer = wavesurfer

    // Listen for when WaveSurfer's backend initializes
    // We'll intercept the audio graph after the source is created
    wavesurfer.on('init', () => {
      console.log("EQ: WaveSurfer init event")
      this.interceptAudioGraph()
    })

    // Also try immediately if already initialized
    if (wavesurfer.backend) {
      console.log("EQ: WaveSurfer backend already exists")
      this.interceptAudioGraph()
    }
  }

  /**
   * Intercept and modify WaveSurfer's audio graph
   * Following the official WaveSurfer webaudio.js example pattern
   */
  interceptAudioGraph() {
    try {
      console.log("EQ: interceptAudioGraph() called, this.wavesurfer =", this.wavesurfer)

      if (!this.wavesurfer) {
        console.warn("EQ: No wavesurfer instance stored, trying to get it now...")

        // Try to get WaveSurfer instance now
        const playerElement = document.querySelector('[data-controller*="music--player"]')
        if (!playerElement) {
          console.error("EQ: Player element not found")
          return
        }

        const playerController = this.application.getControllerForElementAndIdentifier(
          playerElement,
          "music--player"
        )

        if (!playerController?.wavesurfer) {
          console.error("EQ: WaveSurfer not available on player controller")
          return
        }

        // Store it and continue
        this.wavesurfer = playerController.wavesurfer
        console.log("EQ: Got WaveSurfer instance:", this.wavesurfer)
      }

      // Only initialize once
      if (this.isConnected) {
        console.log("EQ: Already connected")
        return
      }

      console.log("EQ: Attempting to intercept audio graph")

      // Get the HTML audio element from WaveSurfer
      // WaveSurfer uses MediaElement backend, so this is a plain HTMLAudioElement
      const audioElement = this.wavesurfer.media

      if (!audioElement || !(audioElement instanceof HTMLMediaElement)) {
        console.error("EQ: Could not get HTML audio element from WaveSurfer")
        console.error("EQ: audioElement:", audioElement)
        return
      }

      console.log("EQ: Got HTML audio element:", audioElement)

      // Create our own Web Audio context
      if (!this.audioContext) {
        this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
        console.log("EQ: Created AudioContext:", this.audioContext)
      }

      // Create MediaElementSource from the audio element
      // This connects the HTML5 audio to Web Audio API
      if (!this.sourceNode) {
        try {
          this.sourceNode = this.audioContext.createMediaElementSource(audioElement)
          console.log("EQ: Created MediaElementSource:", this.sourceNode)
        } catch (error) {
          console.error("EQ: Failed to create MediaElementSource:", error)
          console.error("EQ: This usually means the element is already connected")
          return
        }
      }

      // Create filter nodes (following WaveSurfer example: lowshelf, peaking, highshelf)
      if (this.filterNodes.length === 0) {
        this.filterNodes = this.frequencies.map((freq, index) => {
          const filter = this.audioContext.createBiquadFilter()

          // Use appropriate filter types like the official example
          if (index === 0) {
            filter.type = "lowshelf"  // First band (32Hz)
          } else if (index === this.frequencies.length - 1) {
            filter.type = "highshelf" // Last band (16kHz)
          } else {
            filter.type = "peaking"   // Middle bands
          }

          filter.frequency.value = freq
          filter.Q.value = 1.0
          filter.gain.value = this.currentGains[index]
          return filter
        })
        console.log("EQ: Created filter nodes:", this.filterNodes.length)
      }

      // Disconnect existing connections
      try {
        this.sourceNode.disconnect()
      } catch (e) {
        console.log("EQ: Source node already disconnected")
      }

      // Chain filters sequentially (following WaveSurfer example pattern)
      // source → filter0 → filter1 → ... → filter9 → destination
      this.filterNodes.reduce((prev, curr) => {
        prev.connect(curr)
        return curr
      }, this.sourceNode).connect(this.audioContext.destination)

      this.isConnected = true
      console.log("EQ: ✓ Successfully connected audio graph!")
      console.log("EQ: Audio path: MediaElement → 10 Filters → Destination")

      // Signal to player that EQ is ready
      document.dispatchEvent(new CustomEvent("equalizer:ready"))
      console.log("EQ: Dispatched equalizer:ready event")

    } catch (error) {
      console.error("EQ: Error intercepting audio graph:", error)
      console.error(error.stack)
    }
  }

  disconnect() {
    window.removeEventListener("audio:changed", this.handleSongChange.bind(this))
    window.removeEventListener("player:state:changed", this.handlePlayerState.bind(this))
    window.removeEventListener("audio:ready", this.handleAudioReady.bind(this))
    this.destroyFilters()
  }

  /**
   * Toggle EQ panel visibility
   */
  togglePanel() {
    this.panelTarget.classList.toggle("hidden")

    // If opening panel and EQ not initialized, try to initialize
    if (!this.panelTarget.classList.contains("hidden") && !this.isConnected) {
      // Check if we can initialize
      this.checkWebAudioAvailability()
    }
  }

  /**
   * Check if Web Audio API is available in the BROWSER
   * Note: WaveSurfer uses MediaElement backend, but WE create our own Web Audio chain
   */
  checkWebAudioAvailability() {
    // Check if browser supports Web Audio API
    const hasWebAudio = !!(window.AudioContext || window.webkitAudioContext)

    console.log("EQ: Browser Web Audio API support:", hasWebAudio)

    if (!hasWebAudio) {
      // Show unavailable message, hide EQ controls
      console.log("EQ: WebAudio not available in browser - showing error message")
      if (this.hasUnavailableMessageTarget) {
        this.unavailableMessageTarget.classList.remove("hidden")
      }
      if (this.hasHeaderContentTarget) {
        this.headerContentTarget.classList.add("hidden")
      }
      if (this.hasMainContentTarget) {
        this.mainContentTarget.classList.add("hidden")
      }
    } else {
      // Hide unavailable message, show EQ controls
      console.log("EQ: WebAudio available - showing EQ controls")
      if (this.hasUnavailableMessageTarget) {
        this.unavailableMessageTarget.classList.add("hidden")
      }
      if (this.hasHeaderContentTarget) {
        this.headerContentTarget.classList.remove("hidden")
      }
      if (this.hasMainContentTarget) {
        this.mainContentTarget.classList.remove("hidden")
      }
    }
  }

  /**
   * Handle song change event from player
   */
  handleSongChange(event) {
    this.currentSongUrl = event.detail.url
    console.log("EQ: Song changed to:", this.currentSongUrl)

    this.matchSongUrl = this.getStorageKey(this.currentSongUrl)
    
    this.updateSaveButtonState()
    this.updateTriggerIconColor()
  }

  /**
   * Helper to get a stable storage key from a URL
   * Strips query parameters (S3 signatures, timestamps, etc.)
   */
  getStorageKey(url) {
    if (!url) return null;
    return url.split("?")[0];
  }

  /**
   * Handle audio ready event (good time to initialize filters)
   */
  handleAudioReady(event) {
    console.log("EQ: Audio ready event received")

    // Try to intercept audio graph if not already done
    if (!this.isConnected) {
      // Get WaveSurfer and try to hook in
      const playerElement = document.querySelector('[data-controller*="music--player"]')
      if (playerElement) {
        const playerController = this.application.getControllerForElementAndIdentifier(
          playerElement,
          "music--player"
        )

        if (playerController?.wavesurfer) {
          if (!this.wavesurfer) {
            this.hookIntoWaveSurfer(playerController.wavesurfer)
          } else {
            this.interceptAudioGraph()
          }
        }
      }
    }

    // Load saved EQ settings for current song
    if (this.isConnected) {
      this.loadSongSettings()
    }
  }

  /**
   * Handle player state changes
   */
  handlePlayerState(event) {
    // Update save button state based on whether a song is playing
    this.updateSaveButtonState()
  }

  /**
   * Initialize Web Audio API filter nodes (REMOVED - using interceptAudioGraph instead)
   */

  /**
   * Destroy filter nodes
   */
  destroyFilters() {
    try {
      if (this.filterNodes.length > 0) {
        this.filterNodes.forEach(filter => {
          filter.disconnect()
        })
        this.filterNodes = []
      }

      if (this.sourceNode) {
        this.sourceNode.disconnect()
        this.sourceNode = null
      }

      this.isConnected = false
    } catch (error) {
      console.error("EQ: Error destroying filters:", error)
    }
  }

  /**
   * Update a single band's gain
   */
  updateBand(event) {
    const slider = event.target
    const bandIndex = this.getBandIndex(slider)
    const gain = parseFloat(slider.value)

    console.log(`EQ: Band ${bandIndex} (${this.frequencies[bandIndex]}Hz) set to ${gain}dB`)

    // Update current gains array
    this.currentGains[bandIndex] = gain

    // Update the filter node if connected
    if (this.isConnected && this.filterNodes[bandIndex]) {
      this.filterNodes[bandIndex].gain.value = gain
      console.log(`EQ: Filter node ${bandIndex} gain updated to ${gain}dB`)
    } else {
      console.warn(`EQ: Cannot update filter - isConnected: ${this.isConnected}, filterNode exists: ${!!this.filterNodes[bandIndex]}`)

      // Try to intercept audio graph if not connected yet
      if (!this.isConnected) {
        console.log("EQ: Attempting to initialize filters now...")
        this.interceptAudioGraph()
      }
    }

    // Update the gain display
    this.updateGainDisplay(bandIndex, gain)

    // Check if settings differ from saved settings
    this.updateSongIndicator()
  }

  /**
   * Get band index from slider element
   */
  getBandIndex(slider) {
    // Extract index from target name (e.g., "band0" -> 0)
    for (let i = 0; i < 10; i++) {
      if (this[`band${i}Target`] === slider) {
        return i
      }
    }
    return 0 // Fallback
  }

  /**
   * Update gain display label
   */
  updateGainDisplay(bandIndex, gain) {
    const displayTarget = this[`gainDisplay${bandIndex}Target`]
    if (displayTarget) {
      const sign = gain > 0 ? "+" : ""
      displayTarget.textContent = `${sign}${gain}dB`
    }
  }

  /**
   * Apply a preset
   */
  applyPreset(event) {
    const presetName = event.target.dataset.preset
    const gains = this.presets[presetName]

    if (!gains) {
      console.error("EQ: Unknown preset:", presetName)
      return
    }

    // Apply gains to sliders and filters
    this.applyGains(gains)
  }

  /**
   * Apply gain values to all bands
   */
  applyGains(gains) {
    gains.forEach((gain, index) => {
      // Update slider
      const slider = this[`band${index}Target`]
      if (slider) {
        slider.value = gain
      }

      // Update filter node
      if (this.isConnected && this.filterNodes[index]) {
        this.filterNodes[index].gain.value = gain
      }

      // Update current gains
      this.currentGains[index] = gain

      // Update display
      this.updateGainDisplay(index, gain)
    })

    this.updateSongIndicator()
  }

  /**
   * Reset to flat (no EQ)
   */
  reset() {
    this.applyGains(this.presets["flat"])

    // If a song is playing, remove its saved settings
    if (this.currentSongUrl) {
      this.removeSongSettings()
    }
  }

  /**
   * Save current EQ settings for the current song
   */
  saveForSong() {
    if (!this.currentSongUrl) {
      console.warn("EQ: No song currently playing")
      return
    }

    // Get EQ settings from localStorage
    const settings = this.getEQSettings()

    // Use consistent storage key
    this.matchSongUrl = this.getStorageKey(this.currentSongUrl)

    // Save current gains for this song
    settings[this.matchSongUrl] = {
      gains: [...this.currentGains],
      timestamp: Date.now()
    }

    // Save back to localStorage
    localStorage.setItem("zuke_eq_settings", JSON.stringify(settings))
    console.log("EQ: Saved settings for song:", this.matchSongUrl, "Gains:", this.currentGains)

    // Update indicator
    this.updateSongIndicator()

    // Show feedback
    this.showSaveFeedback()

    // Dispatch event so song cards can update their indicators
    console.log("EQ: Dispatching equalizer:saved event for:", this.matchSongUrl)
    document.dispatchEvent(new CustomEvent("equalizer:saved", {
      detail: { url: this.currentSongUrl }
    }))

    // Update trigger icon color
    this.updateTriggerIconColor()
  }

  /**
   * Load saved EQ settings for current songF
   */
  loadSongSettings() {
    if (!this.matchSongUrl) return

    const settings = this.getEQSettings()
    const songSettings = settings[this.matchSongUrl]

    if (songSettings && songSettings.gains) {
      // Apply saved gains
      this.applyGains(songSettings.gains)
      console.log("EQ: Loaded saved settings for song")
    } else {
      // Reset to flat for songs without custom EQ
      this.applyGains(this.presets["flat"])
    }

    // Update trigger icon color
    this.updateTriggerIconColor()
  }

  /**
   * Remove saved settings for current song
   */
  removeSongSettings() {
    if (!this.matchSongUrl) return

    const settings = this.getEQSettings()
    delete settings[this.matchSongUrl]
    localStorage.setItem("zuke_eq_settings", JSON.stringify(settings))

    this.updateSongIndicator()

    // Dispatch event so song cards can update
    document.dispatchEvent(new CustomEvent("equalizer:removed", {
      detail: { url: this.matchSongUrl }
    }))

    // Update trigger icon color
    this.updateTriggerIconColor()
  }

  /**
   * Get EQ settings from localStorage
   */
  getEQSettings() {
    try {
      const json = localStorage.getItem("zuke_eq_settings")
      return json ? JSON.parse(json) : {}
    } catch (error) {
      console.error("EQ: Error reading settings:", error)
      return {}
    }
  }

  /**
   * Check if current song has saved settings
   */
  hasSavedSettings(url = this.matchSongUrl) {
    if (!url) return false
    const settings = this.getEQSettings()
    return !!settings[url]
  }

  /**
   * Update song indicator visibility
   */
  updateSongIndicator() {
    if (!this.hasSongIndicatorTarget) return

    if (this.hasSavedSettings()) {
      this.songIndicatorTarget.classList.remove("hidden")
    } else {
      this.songIndicatorTarget.classList.add("hidden")
    }
  }

  /**
   * Update trigger icon color based on current song's EQ settings
   * Gold/amber when custom EQ exists, white when no custom EQ
   */
  updateTriggerIconColor() {
    if (!this.hasTriggerIconTarget) return

    if (this.hasSavedSettings()) {
      // Current song has custom EQ - make icon amber/gold
      this.triggerIconTarget.classList.remove("text-white")
      this.triggerIconTarget.classList.add("text-amber-400")
      console.log("EQ: Icon color changed to amber (custom EQ active)")
    } else {
      // No custom EQ - make icon white
      this.triggerIconTarget.classList.remove("text-amber-400")
      this.triggerIconTarget.classList.add("text-white")
      console.log("EQ: Icon color changed to white (no custom EQ)")
    }
  }

  /**
   * Update save button state
   */
  updateSaveButtonState() {
    if (!this.hasSaveButtonTarget) return

    if (this.currentSongUrl) {
      this.saveButtonTarget.disabled = false
      this.saveButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
    } else {
      this.saveButtonTarget.disabled = true
      this.saveButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
  }

  /**
   * Show visual feedback when settings are saved
   */
  showSaveFeedback() {
    if (!this.hasSaveButtonTarget) return

    const originalText = this.saveButtonTarget.textContent
    this.saveButtonTarget.textContent = "Saved!"
    this.saveButtonTarget.classList.add("bg-green-600")
    this.saveButtonTarget.classList.remove("bg-teal-600")

    setTimeout(() => {
      this.saveButtonTarget.textContent = originalText
      this.saveButtonTarget.classList.remove("bg-green-600")
      this.saveButtonTarget.classList.add("bg-teal-600")
    }, 1500)
  }
}
