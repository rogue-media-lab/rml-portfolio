import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurfer.js"

/**
 * Global Audio Player Controller
 * 
 * Manages core audio playback functionality including:
 * - WaveSurfer initialization and management
 * - Track loading and playback control
 * - Event handling and state management
 * - Error handling and recovery
 */
export default class extends Controller {
  // ========================
  //  Configuration
  // ========================

  /**
   * DOM Element Targets
   * @type {string[]}
   */
  static targets = [
    "waveform",          // WaveSurfer visualization container
    "loadingProgress",   // Loading progress bar element
  ]

  /**
   * Controller Values
   * @type {Object}
   */
  static values = {
    autoAdvance: { type: Boolean, default: false },
    shuffle: { type: Boolean, default: false },
    repeatMode: { type: String, default: "off" }, // 'off', 'all', 'one'
  }


  /**
   * Current track URL reference
   * @type {?string}
   */
  currentUrl = null

  // ========================
  //  Lifecycle Methods
  // ========================

  /**
   * Initialize controller when connected to DOM
   * Sets up WaveSurfer instance and event listeners
   */
  connect() {
    this.initializeWaveSurfer();
    this.setupEventListeners();
    this.setupMobileAudioContext();

    // 1. Initialize playback state from localStorage
    const autoAdvance = localStorage.getItem("playerAutoAdvance") === "true";
    this.autoAdvanceValue = autoAdvance;

    const playOnLoad = localStorage.getItem("audioPlayOnLoad") === "true";
    this.playOnLoadValue = playOnLoad;

    const shuffle = localStorage.getItem("playerShuffle") === "true";
    this.shuffleValue = shuffle;

    // Initialize repeat mode (migrates from old auto-advance if needed)
    const repeatMode = localStorage.getItem("playerRepeat") || (autoAdvance ? "all" : "off");
    this.repeatModeValue = repeatMode;

    // 2. Initialize queue state
    this.currentQueue = [];
    this.currentIndex = -1;
    this.currentUrl = null;
    this.recentlyPlayed = []; // Track recently played songs for shuffle

    // 3. Sync initial states
    document.dispatchEvent(new CustomEvent("player:auto-advance:changed", {
      detail: { enabled: this.autoAdvanceValue }
    }));

    document.dispatchEvent(new CustomEvent("player:play-on-load:changed", {
      detail: { enabled: this.playOnLoadValue }
    }));

    document.dispatchEvent(new CustomEvent("player:shuffle:changed", {
      detail: { enabled: this.shuffleValue }
    }));

    // 4. REQUEST queue from song-list controller
    console.log("🎵 PLAYER: Requesting queue from song-list controller")
    setTimeout(() => {
      document.dispatchEvent(new CustomEvent("player:queue:request"))
    }, 50)

    // 5. Queue listener remains important!
    document.addEventListener("player:queue:updated", (event) => {
      
      // Improved queue update with validation
      this.currentQueue = Array.isArray(event.detail.queue) ? event.detail.queue : [];
      
      // More robust index finding
      this.currentIndex = this.currentQueue.findIndex(song => {
        return song?.url === this.currentUrl;
      });
    });
  }

  /**
   * Clean up when controller is disconnected
   * Stops playback and destroys WaveSurfer instance
   */
  disconnect() {
    this.destroyWaveSurfer()
  }

  // ========================
  //  Core Audio Setup
  // ========================

  /**
   * Detect if running on mobile device
   * Uses multiple detection methods for better accuracy
   * @returns {boolean}
   */
  isMobile() {
    // Check user agent for mobile devices
    const mobileUA = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)

    // Check for touch-only devices (excludes laptops with touchscreens)
    const isTouchDevice = ('ontouchstart' in window) &&
                          (navigator.maxTouchPoints > 0) &&
                          !window.matchMedia("(pointer: fine)").matches

    // Check screen width as secondary indicator (typical phone/tablet sizes)
    const isSmallScreen = window.innerWidth <= 768

    // Consider it mobile if: (mobile UA OR touch-only device) AND small screen
    // This prevents laptops from being detected as mobile
    return (mobileUA || isTouchDevice) && isSmallScreen
  }

  /**
   * Initialize WaveSurfer audio instance
   * Creates and configures the WaveSurfer player with visualization options
   */
  initializeWaveSurfer() {
    try {
      // IMPORTANT: Use MediaElement backend so EQ can create its own Web Audio chain
      // WebAudio backend hides audio nodes, making EQ impossible
      const backend = "MediaElement"

      console.log(`Initializing WaveSurfer with ${backend} backend (for EQ compatibility)`)

      this.wavesurfer = WaveSurfer.create({
        container: this.waveformTarget,
        waveColor: "#00B1D1",
        progressColor: "#01DFB6",
        height: 50,
        minPxPerSec: 50,
        hideScrollbar: true,
        autoScroll: true,
        autoCenter: true,
        dragToSeek: true,
        barWidth: 2,
        barGap: 1,
        barRadius: 2,
        responsive: true,
        backend: backend
      })
      this.setupWaveSurferEvents()
    } catch (error) {
      console.error("WaveSurfer initialization failed:", error)
      this.element.classList.add("player-error-state")
    }
  }

  /**
   * Set up WaveSurfer event listeners
   * Handles playback state changes, loading progress, and errors
   */
  setupWaveSurferEvents() {
    // Playback state events
    this.wavesurfer.on("ready", this.handleTrackReady.bind(this))
    this.wavesurfer.on("play", this.handlePlay.bind(this))
    this.wavesurfer.on("pause", this.handlePause.bind(this))
    this.wavesurfer.on("finish", this.handleTrackEnd.bind(this))

    // Loading events
    this.wavesurfer.on("loading", this.handleLoadingProgress.bind(this))
    this.wavesurfer.on("error", this.handleAudioError.bind(this))

    // Time updates
    this.wavesurfer.on("timeupdate", this.updateTimeDisplay.bind(this))
  }

  /**
   * Set up mobile audio context handling
   * Ensures audio continues playing when screen locks or app is backgrounded
   */
  setupMobileAudioContext() {
    if (!this.isMobile()) {
      console.log("🎵 MOBILE AUDIO: Not on mobile, skipping context setup")
      return
    }

    console.log("🎵 MOBILE AUDIO: Setting up mobile audio handling for MediaElement backend")

    // For MediaElement backend, we need to ensure the HTML5 audio element is properly configured
    // The Media Session API will handle most of the background playback

    // Listen for visibility changes to handle app backgrounding
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden && this.wavesurfer?.isPlaying()) {
        console.log("🎵 MOBILE AUDIO: App visible again, verifying playback state")

        // Ensure audio element is playing
        const mediaElement = this.wavesurfer.getMediaElement()
        if (mediaElement && mediaElement.paused && this.wavesurfer.isPlaying()) {
          console.log("🎵 MOBILE AUDIO: Resuming paused media element")
          mediaElement.play().catch(error => {
            console.warn("🎵 MOBILE AUDIO: Could not resume playback:", error)
          })
        }
      }
    })

    console.log("🎵 MOBILE AUDIO: Mobile audio handlers configured")
  }

  // ========================
  //  Event Handling
  // ========================

  /**
   * Set up custom DOM event listeners
   * Listens for external playback commands
   */
  setupEventListeners() {
    // Existing listeners
    window.addEventListener("player:play-requested", this.handlePlayRequest.bind(this));
    document.addEventListener("player:play", () => {
      const playPromise = this.wavesurfer.play()
      if (playPromise !== undefined) {
        playPromise.catch((error) => {
          console.warn("Play blocked:", error)
        })
      }
    });
    document.addEventListener("player:pause", () => this.wavesurfer.pause());

    document.addEventListener("player:auto-advance:changed", (event) => {
      this.autoAdvanceValue = event.detail.enabled
    })

    document.addEventListener("player:play-on-load:changed", (event) => {
      this.playOnLoadValue = event.detail.enabled
    })

    document.addEventListener("player:shuffle:changed", (event) => {
      this.shuffleValue = event.detail.enabled
    })

    document.addEventListener("player:repeat:changed", (event) => {
      this.repeatModeValue = event.detail.mode
      console.log("🔁 Player received repeat mode change:", this.repeatModeValue)
    })

    // Add the queue update listener
    document.addEventListener("player:queue:updated", (event) => {
      this.currentQueue = event.detail.queue;

      // Sync index if we"re already playing a song
      if (this.currentUrl) {
        const currentSong = this.currentQueue.find(song => song.url === this.currentUrl);
        if (currentSong) {
          this.setCurrentIndex(currentSong.id);
        }
      }
    });

    // Listen for sync requests and broadcast current state
    window.addEventListener("player:sync-request", () => {
      if (this.currentUrl) {
        window.dispatchEvent(new CustomEvent("audio:changed", {
          detail: { url: this.currentUrl }
        }))
      }
    })

    // Media Session API event handlers
    document.addEventListener("player:next:requested", (event) => {
      console.log("🎵 PLAYER: Next track requested via", event.detail?.source || 'unknown')
      this.playNext()
    })

    document.addEventListener("player:prev:requested", (event) => {
      console.log("🎵 PLAYER: Previous track requested via", event.detail?.source || 'unknown')
      this.playPrevious()
    })

    // Seek handlers for Media Session API
    document.addEventListener("player:seek:forward", (event) => {
      const seconds = event.detail.seconds || 10
      console.log("🎵 PLAYER: Seek forward requested:", seconds, "seconds")
      this.seekRelative(seconds)
    })

    document.addEventListener("player:seek:backward", (event) => {
      const seconds = event.detail.seconds || 10
      console.log("🎵 PLAYER: Seek backward requested:", seconds, "seconds")
      this.seekRelative(-seconds)
    })
  }

  // ========================
  //  Playback State Handlers
  // ========================

  /**
   * Handle track loaded and ready to play
   * Updates UI and dispatches ready state
   */
  handleTrackReady() {
    try {
      this.updateTimeDisplay(0)
      this.hideLoadingIndicator()
      this.dispatchStateChange()

      // Notify that audio is ready - safe to load video now
      window.dispatchEvent(new CustomEvent("audio:ready", {
        detail: { url: this.currentUrl }
      }))
    } catch (error) {
      console.error("Error handling track ready:", error)
      this.handleAudioError()
    }
  }

  /**
   * Handle play state change
   */
  handlePlay() {
    this.dispatchStateChange(true)
  }

  /**
   * Handle pause state change
   */
  handlePause() {
    this.dispatchStateChange(false)
  }

  /**
   * Handle track ending naturally
   */
  handleTrackEnd() {
    console.log("🎵 Track ended - Repeat:", this.repeatModeValue, "Shuffle:", this.shuffleValue, "Queue length:", this.currentQueue.length)

    // Dispatch ended event BEFORE state changes
    window.dispatchEvent(new CustomEvent("audio:ended", {
      detail: { url: this.currentUrl }
    }))

    // Update play/pause state
    this.handlePause()

    // Handle repeat modes
    if (this.repeatModeValue === 'one') {
      // Repeat One: replay the same song
      console.log("🔁 Repeat One - replaying current track")
      try {
        this.wavesurfer.seekTo(0)
        const playPromise = this.wavesurfer.play()
        if (playPromise !== undefined) {
          playPromise.catch((error) => {
            console.warn("🚫 Repeat One autoplay blocked:", error)
          })
        }
      } catch (error) {
        console.error("❌ Error repeating track:", error)
        this.resetPlayback()
      }
    } else if (this.repeatModeValue === 'all' && this.currentQueue.length > 0) {
      // Repeat All: play next track (loops back to start)
      console.log("🔁 Repeat All - playing next track...")
      try {
        // CRITICAL: Call playNext() immediately to preserve iOS gesture context
        // setTimeout would break the autoplay permission on iOS Safari
        console.log("▶️ Calling playNext() immediately...")
        this.playNext()
      } catch (error) {
        console.error("❌ Error during repeat all:", error)
        this.resetPlayback()
      }
    } else {
      // Repeat Off: stop playback
      console.log("⏸️ Repeat Off - stopping playback")
      this.resetPlayback()
    }
  }

  /**
   * Ensure AudioContext is resumed (critical for mobile Safari with WebAudio backend)
   */
  async ensureAudioContextResumed() {
    try {
      // Only needed for WebAudio backend
      if (this.isMobile()) {
        const mediaElement = this.wavesurfer?.getMediaElement?.()
        if (mediaElement && mediaElement.context && mediaElement.context.state === 'suspended') {
          console.log("Resuming suspended AudioContext...")
          await mediaElement.context.resume()
        }
      }
    } catch (error) {
      console.warn("Could not resume AudioContext:", error)
    }
  }

  /**
   * Dispatch player state change event
   * @param {boolean} [playing] - Optional play/pause state
   */
  dispatchStateChange(playing) {
    document.dispatchEvent(new CustomEvent("player:state:changed", {
      detail: { 
        playing: playing ?? this.wavesurfer.isPlaying(),
        url: this.currentUrl 
      }
    }))
  }

  // ========================
  //  Playback Control
  // ========================

  /**
   * Handle external play event (from song cards)
   * @param {Event} e - Custom play event containing track details
   */
  handlePlayRequest(e) {
    try {
      const {
        id, url, title, artist, banner, bannerMobile, bannerVideo, playOnLoad = false, updateBanner,
        imageCredit, imageCreditUrl, imageLicense, audioSource, audioLicense, additionalCredits
      } = e.detail

      this.setCurrentIndex(id)

      // Start audio loading FIRST (priority)
      if (!this.wavesurfer || this.currentUrl !== url) {
        this.loadTrack(url, playOnLoad)
      } else {
        this.togglePlayback()
      }

      // Then update UI (non-blocking, can happen in parallel)
      if (updateBanner !== false) {
        this.updateBanner({ banner, bannerMobile, bannerVideo, title, artist })
      }

      // Update credits display
      this.updateCredits({
        title,
        artist,
        imageCredit,
        imageCreditUrl,
        imageLicense,
        audioSource,
        audioLicense,
        additionalCredits
      })
    } catch (error) {
      console.error("Error handling play event:", error)
      this.handleAudioError()
    }
  }

  /**
   * Dispatch play request for a song
   * @param {Object} song - Song object
   */
  dispatchPlayRequest(song) {
    window.dispatchEvent(new CustomEvent("player:play-requested", {
      detail: {
        url: song.url,
        title: song.title,
        artist: song.artist,
        banner: song.banner,
        bannerMobile: song.bannerMobile,
        bannerVideo: song.bannerVideo,
        autoplay: true,
        updateBanner: true
      }
    }))
  }

  /**
   * Play the next song in queue
   */
  playNext() {
    console.log("🔄 playNext() called - Index:", this.currentIndex, "Queue:", this.currentQueue.length, "Shuffle:", this.shuffleValue)

    if (this.currentQueue.length === 0) {
      console.warn("⚠️ Cannot play next - queue is empty")
      return;
    }

    if (!Array.isArray(this.currentQueue)) {
      console.error("❌ Queue is not an array!", this.currentQueue)
      return;
    }

    let nextIndex;

    if (this.shuffleValue) {
      // Shuffle mode: pick random song avoiding recently played
      nextIndex = this.getRandomIndex();
    } else {
      // Normal mode: sequential playback
      nextIndex = (this.currentIndex + 1) % this.currentQueue.length;

      // Verify we're actually moving to a new track
      if (nextIndex === this.currentIndex && this.currentQueue.length > 1) {
        nextIndex = 0; // Wrap around to start
      }
    }

    this.currentIndex = nextIndex;
    const nextSong = this.currentQueue[this.currentIndex];

    console.log("🎶 Next song selected:", nextSong?.title, "by", nextSong?.artist, "at index:", this.currentIndex)

    // Verify we have a valid song to play
    if (!nextSong) {
      console.error("❌ Next song is null/undefined at index:", nextIndex)
      return;
    }

    if (!nextSong.url) {
      console.error("❌ Next song has no URL:", nextSong)
      return;
    }

    if (nextSong.url === this.currentUrl) {
      console.warn("⚠️ Next song is same as current - skipping")
      return;
    }

    // Track recently played for shuffle
    this.trackRecentlyPlayed(nextIndex);

    console.log("✅ Calling playSongFromQueue() for:", nextSong.title)
    this.playSongFromQueue(nextSong);
  }

  /**
   * Get random index avoiding recently played songs
   */
  getRandomIndex() {
    const queueLength = this.currentQueue.length;

    // If queue is small, just pick random
    if (queueLength <= 3) {
      return Math.floor(Math.random() * queueLength);
    }

    // Build available indices (excluding recently played)
    const maxRecent = Math.min(5, Math.floor(queueLength / 3)); // Track last 5 or 1/3 of queue
    const recentSet = new Set(this.recentlyPlayed.slice(-maxRecent));

    const availableIndices = [];
    for (let i = 0; i < queueLength; i++) {
      if (!recentSet.has(i) && i !== this.currentIndex) {
        availableIndices.push(i);
      }
    }

    // If no available indices (shouldn't happen), reset recently played
    if (availableIndices.length === 0) {
      this.recentlyPlayed = [];
      return Math.floor(Math.random() * queueLength);
    }

    // Pick random from available
    return availableIndices[Math.floor(Math.random() * availableIndices.length)];
  }

  /**
   * Track recently played song index
   */
  trackRecentlyPlayed(index) {
    this.recentlyPlayed.push(index);

    // Keep only last 10
    if (this.recentlyPlayed.length > 10) {
      this.recentlyPlayed.shift();
    }
  }

  playPrevious() {
    if (this.currentQueue.length === 0) return
    
    this.currentIndex = (this.currentIndex - 1 + this.currentQueue.length) % this.currentQueue.length
    const prevSong = this.currentQueue[this.currentIndex]
    this.playSongFromQueue(prevSong)
  }

  playSongFromQueue(song) {
    try {
      console.log("🎵 playSongFromQueue() called with:", song?.title)

      if (!song || !song.url) {
        console.error("❌ Invalid song object in queue:", song);
        return;
      }

      // Clear current track completely before loading new one
      this.wavesurfer?.stop();
      this.wavesurfer?.empty();

      // Update UI first
      this.updateBanner({
        banner: song.banner,
        bannerMobile: song.bannerMobile,
        bannerVideo: song.bannerVideo,
        title: song.title,
        artist: song.artist
      });

      // Update credits
      this.updateCredits({
        title: song.title,
        artist: song.artist,
        imageCredit: song.imageCredit,
        imageCreditUrl: song.imageCreditUrl,
        imageLicense: song.imageLicense,
        audioSource: song.audioSource,
        audioLicense: song.audioLicense,
        additionalCredits: song.additionalCredits
      });

      // Set current URL before loading
      this.currentUrl = song.url;

      // Dispatch play request
      this.dispatchTrackChange(song.url)

      console.log("📥 Loading track:", song.title, "URL:", song.url.substring(0, 50) + "...")

      // Load and play immediately - no setTimeout delay
      // This keeps the user gesture context alive for mobile Safari
      this.wavesurfer.load(song.url);
      this.wavesurfer.once('ready', () => {
        console.log("✅ Track ready, attempting to play...")

        // Use promise-based play() to handle autoplay blocking
        const playPromise = this.wavesurfer.play();

        // Handle play promise for mobile Safari autoplay restrictions
        if (playPromise !== undefined) {
          playPromise
            .then(() => {
              console.log("🎉 Playback started successfully for:", song.title)
            })
            .catch((error) => {
              console.error("🚫 Autoplay blocked by browser:", error);
              console.log("ℹ️ User interaction required to continue playback")
              // Optionally dispatch event to show "Click to continue" UI
              document.dispatchEvent(new CustomEvent("player:autoplay-blocked", {
                detail: { song: song }
              }));
            });
        } else {
          console.log("✅ Play promise undefined - playback should have started")
        }
      });

    } catch (error) {
      console.error("Error playing from queue:", error);
      this.handleAudioError();
    }
  }


  /**
   * Toggle between play and pause states
   */
  togglePlayback() {
    this.wavesurfer.playPause()
  }

  /**
   * Seek relative to current position
   * @param {number} seconds - Number of seconds to seek (positive = forward, negative = backward)
   */
  seekRelative(seconds) {
    if (!this.wavesurfer) return

    const currentTime = this.wavesurfer.getCurrentTime()
    const duration = this.wavesurfer.getDuration()
    const newTime = Math.max(0, Math.min(duration, currentTime + seconds))

    console.log("🎵 PLAYER: Seeking from", currentTime, "to", newTime)
    this.wavesurfer.seekTo(newTime / duration)
  }

  // ========================
  //  Track Loading
  // ========================

  /**
   * Load a new audio track
   * @param {string} url - Audio file URL
   * @param {boolean} [playOnLoad=false] - Whether to playOnLoad when loaded
   */
  loadTrack(url, playOnLoad = false) {
    try {
      this.resetPlayback()
      this.showLoadingIndicator()
      this.dispatchTrackChange(url)
      
      setTimeout(() => {
        this.wavesurfer.load(url)
      }, 100)
      this.setupPlayOnLoad(playOnLoad)
    } catch (error) {
      console.error("Error loading track:", error)
      this.handleAudioError()
    }
  }

  /**
   * Reset playback state before loading new track
   */
  resetPlayback() {
    try {
      this.wavesurfer?.stop();
      this.wavesurfer?.empty();
      this.wavesurfer?.setTime(0);
    } catch (error) {
      console.error("Error resetting playback:", error);
    }
  }

  /**
   * Dispatch track change event
   * @param {string} url - New track URL
   */
  dispatchTrackChange(url) {
    this.currentUrl = url
    window.dispatchEvent(new CustomEvent("audio:changed", { detail: { url } }))
  }

  /**
   * Configure playOnLoad if requested
   * @param {boolean} playOnLoad - Whether to playOnLoad
   */
  setupPlayOnLoad(playOnLoad) {
    if (playOnLoad) {
      this.wavesurfer.once("ready", () => {
        const playPromise = this.wavesurfer.play()
        if (playPromise !== undefined) {
          playPromise.catch((error) => {
            console.warn("Autoplay blocked on load:", error)
          })
        }
      })
    }
  }

  /**
   * Toggle autoAdvance state
   */
  toggleAutoAdvance() {
    this.autoAdvanceValue = !this.autoAdvanceValue
    this.updateAutoAdvanceUI()
    
    // Dispatch event to inform other components
    document.dispatchEvent(new CustomEvent("player:auto-advance:changed", {
      detail: { enabled: this.autoAdvanceValue }
    }))
  }

  // Set the current index in the queue
  // Use selected song ID to relate to position in queue
  setCurrentIndex(songId) {
    if (!this.currentQueue || this.currentQueue.length === 0) {
      console.warn("Cannot set index for empty queue");
      this.currentIndex = -1;
      return;
    };
    
    // Find the index by matching ID
    const index = this.currentQueue.findIndex(song => song.id.toString() === songId.toString());
    
    if (index >= 0) {
      this.currentIndex = index;
    } else {
      console.warn("Song ID not found in queue:", songId);
      this.currentIndex = 0; // Fallback to first song
    }
  }

  // ========================
  //  UI Updates
  // ========================

  /**
   * Update time display
   * @param {number} currentTime - Current playback position in seconds
   */
  updateTimeDisplay(currentTime) {
    if (this.wavesurfer.getDuration()) {
      document.dispatchEvent(new CustomEvent("player:time:update", {
        detail: {
          current: currentTime,
          duration: this.wavesurfer.getDuration()
        }
      }))
    }
  }

  /**
   * Update banner display
   * @param {Object} details - Banner details
   */
  updateBanner({ banner, bannerMobile, bannerVideo, title, artist }) {
    document.dispatchEvent(new CustomEvent("music:banner:update", {
      detail: {
        image: banner,
        imageMobile: bannerMobile,
        video: bannerVideo,
        title: title || "Unknown Track",
        subtitle: artist || "Unknown Artist"
      }
    }))
  }

  /**
   * Update credits display
   * @param {Object} details - Credits details
   */
  updateCredits({ title, artist, imageCredit, imageCreditUrl, imageLicense, audioSource, audioLicense, additionalCredits }) {
    console.log("Player dispatching credits update:", {
      title, artist, imageCredit, imageCreditUrl, imageLicense, audioSource, audioLicense, additionalCredits
    })
    document.dispatchEvent(new CustomEvent("music:credits:update", {
      detail: {
        title: title || "Unknown Track",
        artist: artist || "Unknown Artist",
        imageCredit,
        imageCreditUrl,
        imageLicense,
        audioSource,
        audioLicense,
        additionalCredits
      }
    }))
  }

  /**
   * Update autoplay button UI
   */
  updateAutoAdvanceUI() {
    const btn = this.element.querySelector("#autoAdvance-toggle")
    if (this.autoAdvanceValue) {
      btn.classList.add("text-green-400")
      btn.classList.remove("text-gray-400")
    } else {
      btn.classList.add("text-gray-400")
      btn.classList.remove("text-green-400")
    }
  }

  // ========================
  //  Loading States
  // ========================

  /**
   * Handle loading progress updates
   * @param {number} progress - Loading percentage (0-100)
   */
  handleLoadingProgress(progress) {
    const smoothedProgress = this.calculateSmoothedProgress(progress)
    this.loadingProgressTarget.style.width = `${smoothedProgress}%`
    
    if (progress === 100) {
      setTimeout(() => this.completeLoading(), 500)
    }
  }

  /**
   * Calculate smoothed loading progress
   */
  calculateSmoothedProgress(progress) {
    const currentWidth = parseFloat(this.loadingProgressTarget.style.width) || 0
    return currentWidth + (progress - currentWidth) * 0.3 // Smoothing factor
  }

  /**
   * Complete loading transition
   */
  completeLoading() {
    this.loadingProgressTarget.classList.add("transition-none")
    this.loadingProgressTarget.style.width = "100%"
  }

  /**
   * Show loading indicator
   */
  showLoadingIndicator() {
    this.loadingProgressTarget.style.width = "0%"
    this.loadingProgressTarget.classList.remove("transition-none")
  }

  /**
   * Hide loading indicator
   */
  hideLoadingIndicator() {
    this.loadingProgressTarget.style.width = "0%"
    this.loadingProgressTarget.classList.remove("transition-none")
  }

  /**
   * Set the current play queue
   * @param {Array} queue - Array of song objects
   */
  setQueue(queue) {
    this.currentQueue = queue
    this.currentIndex = queue.findIndex(song => song.url === this.currentUrl)
  }

  // ========================
  //  Error Handling
  // ========================

  /**
   * Handle audio errors
   */
  handleAudioError() {
    this.hideLoadingIndicator()
    window.dispatchEvent(new CustomEvent("audio:error", {
      detail: { url: this.currentUrl }
    }))
  }

  // ========================
  //  Cleanup
  // ========================

  /**
   * Properly destroy WaveSurfer instance
   */
  destroyWaveSurfer() {
    if (this.wavesurfer) {
      try {
        this.wavesurfer.pause()
        this.wavesurfer.destroy()
        this.wavesurfer = null
      } catch (error) {
        console.error("Error destroying WaveSurfer:", error)
      }
    }
  }
}
