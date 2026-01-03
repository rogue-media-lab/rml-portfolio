import { Controller } from "@hotwired/stimulus"

/**
 * Media Session Controller
 *
 * Integrates with the browser's Media Session API to provide:
 * - Lock screen media controls
 * - Background audio playback
 * - Bluetooth/headphone button controls
 * - Metadata display on lock screen
 */
export default class extends Controller {
  currentMetadata = null

  connect() {
    console.log("🎵 MEDIA SESSION: Controller connected")

    // Check if Media Session API is supported
    if (!('mediaSession' in navigator)) {
      console.warn("🎵 MEDIA SESSION: API not supported in this browser")
      return
    }

    this.setupMediaSessionHandlers()
    this.setupEventListeners()
  }

  /**
   * Set up Media Session action handlers
   */
  setupMediaSessionHandlers() {
    console.log("🎵 MEDIA SESSION: Setting up action handlers")

    try {
      // Play action
      navigator.mediaSession.setActionHandler('play', () => {
        console.log("🎵 MEDIA SESSION: Play action triggered")
        document.dispatchEvent(new CustomEvent("player:play"))
      })

      // Pause action
      navigator.mediaSession.setActionHandler('pause', () => {
        console.log("🎵 MEDIA SESSION: Pause action triggered")
        document.dispatchEvent(new CustomEvent("player:pause"))
      })

      // Previous track
      navigator.mediaSession.setActionHandler('previoustrack', () => {
        console.log("🎵 MEDIA SESSION: Previous track action triggered")
        document.dispatchEvent(new CustomEvent("player:prev:requested", {
          detail: { source: 'media-session' }
        }))
      })

      // Next track
      navigator.mediaSession.setActionHandler('nexttrack', () => {
        console.log("🎵 MEDIA SESSION: Next track action triggered")
        document.dispatchEvent(new CustomEvent("player:next:requested", {
          detail: { source: 'media-session' }
        }))
      })

      // Seek backward (optional - 10 seconds)
      navigator.mediaSession.setActionHandler('seekbackward', (details) => {
        console.log("🎵 MEDIA SESSION: Seek backward action triggered")
        document.dispatchEvent(new CustomEvent("player:seek:backward", {
          detail: { seconds: details.seekOffset || 10 }
        }))
      })

      // Seek forward (optional - 10 seconds)
      navigator.mediaSession.setActionHandler('seekforward', (details) => {
        console.log("🎵 MEDIA SESSION: Seek forward action triggered")
        document.dispatchEvent(new CustomEvent("player:seek:forward", {
          detail: { seconds: details.seekOffset || 10 }
        }))
      })

      console.log("🎵 MEDIA SESSION: Action handlers configured successfully")
    } catch (error) {
      console.error("🎵 MEDIA SESSION: Error setting up handlers:", error)
    }
  }

  /**
   * Set up event listeners to update Media Session metadata
   */
  setupEventListeners() {
    // Update metadata when track changes
    document.addEventListener("player:play-requested", (event) => {
      this.updateMetadata(event.detail)
    })

    // Also update metadata when audio actually changes (covers auto-advance cases)
    document.addEventListener("audio:changed", (event) => {
      // Only update if we have the full metadata (from player:play-requested)
      // This event might fire before metadata is available
      if (this.currentMetadata) {
        console.log("🎵 MEDIA SESSION: Audio changed, keeping current metadata")
      }
    })

    // Update playback state
    document.addEventListener("player:state:changed", (event) => {
      this.updatePlaybackState(event.detail.playing)
    })

    // Update position state
    document.addEventListener("player:time:update", (event) => {
      this.updatePositionState(event.detail)
    })
  }

  /**
   * Update Media Session metadata (title, artist, artwork)
   */
  updateMetadata({ title, artist, banner }) {
    if (!('mediaSession' in navigator)) return

    console.log("🎵 MEDIA SESSION: Updating metadata:", { title, artist, banner })

    try {
      // Store current metadata
      this.currentMetadata = { title, artist, banner }

      // Prepare artwork array
      const artwork = []

      if (banner) {
        // Convert relative path to absolute URL
        const artworkUrl = banner.startsWith('http')
          ? banner
          : `${window.location.origin}${banner.startsWith('/') ? '' : '/'}${banner}`

        artwork.push({
          src: artworkUrl,
          sizes: '512x512',
          type: 'image/jpeg'
        })
      }

      navigator.mediaSession.metadata = new MediaMetadata({
        title: title || 'Unknown Track',
        artist: artist || 'Unknown Artist',
        album: 'Zuke Player',
        artwork: artwork
      })

      console.log("🎵 MEDIA SESSION: Metadata updated successfully")
    } catch (error) {
      console.error("🎵 MEDIA SESSION: Error updating metadata:", error)
    }
  }

  /**
   * Update playback state (playing/paused)
   */
  updatePlaybackState(isPlaying) {
    if (!('mediaSession' in navigator)) return

    try {
      navigator.mediaSession.playbackState = isPlaying ? 'playing' : 'paused'
      console.log("🎵 MEDIA SESSION: Playback state updated:", isPlaying ? 'playing' : 'paused')
    } catch (error) {
      console.error("🎵 MEDIA SESSION: Error updating playback state:", error)
    }
  }

  /**
   * Update position state (current time / duration)
   */
  updatePositionState({ current, duration }) {
    if (!('mediaSession' in navigator)) return
    if (!('setPositionState' in navigator.mediaSession)) return

    try {
      navigator.mediaSession.setPositionState({
        duration: duration || 0,
        playbackRate: 1.0,
        position: current || 0
      })
    } catch (error) {
      // Fail silently - position state is not critical
      // Some browsers don't support this yet
    }
  }

  disconnect() {
    console.log("🎵 MEDIA SESSION: Controller disconnected")

    // Clean up Media Session handlers
    if ('mediaSession' in navigator) {
      try {
        navigator.mediaSession.setActionHandler('play', null)
        navigator.mediaSession.setActionHandler('pause', null)
        navigator.mediaSession.setActionHandler('previoustrack', null)
        navigator.mediaSession.setActionHandler('nexttrack', null)
        navigator.mediaSession.setActionHandler('seekbackward', null)
        navigator.mediaSession.setActionHandler('seekforward', null)
      } catch (error) {
        console.error("🎵 MEDIA SESSION: Error cleaning up handlers:", error)
      }
    }
  }
}
