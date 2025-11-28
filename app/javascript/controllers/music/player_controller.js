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
  
    // 1. Initialize playback state from localStorage
    const autoAdvance = localStorage.getItem("playerAutoAdvance") === "true";
    this.autoAdvanceValue = autoAdvance;

    const playOnLoad = localStorage.getItem("audioPlayOnLoad") === "true";
    this.playOnLoadValue = playOnLoad;
    
    // 2. Initialize queue state
    this.currentQueue = [];
    this.currentIndex = -1;
    this.currentUrl = null;
  
    // 3. Sync initial states
    document.dispatchEvent(new CustomEvent("player:auto-advance:changed", {
      detail: { enabled: this.autoAdvanceValue }
    }));

    document.dispatchEvent(new CustomEvent("player:play-on-load:changed", {
      detail: { enabled: this.playOnLoadValue }
    }));
  
    // 4. Queue listener remains important!
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
  async handleTrackEnd() {
    console.log("Track ended - Auto-advance:", this.autoAdvanceValue, "Queue length:", this.currentQueue.length)

    this.handlePause()
    this.resetPlayback()
    window.dispatchEvent(new CustomEvent("audio:ended", {
      detail: { url: this.currentUrl }
    }))

    if (this.autoAdvanceValue && this.currentQueue.length > 0) {
      console.log("Attempting to play next track...")
      // Resume AudioContext for mobile Safari (WebAudio backend only)
      await this.ensureAudioContextResumed()
      this.playNext()
    } else {
      console.log("Not advancing - Auto-advance disabled or empty queue")
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
    console.log("playNext called - Current index:", this.currentIndex, "Queue length:", this.currentQueue.length)

    if (this.currentQueue.length === 0) {
      console.warn("Cannot play next - queue is empty")
      return;
    }

    // Calculate next index safely
    const nextIndex = (this.currentIndex + 1) % this.currentQueue.length;

    // Verify we're actually moving to a new track
    if (nextIndex === this.currentIndex && this.currentQueue.length > 1) {
      this.currentIndex = 0; // Wrap around to start
    } else {
      this.currentIndex = nextIndex;
    }

    const nextSong = this.currentQueue[this.currentIndex];

    console.log("Next song:", nextSong?.title, "at index:", this.currentIndex)

    // Verify we have a valid song to play
    if (!nextSong || nextSong.url === this.currentUrl) {
      console.warn("Invalid next song or same as current");
      return;
    }

    this.playSongFromQueue(nextSong);
  }

  playPrevious() {
    if (this.currentQueue.length === 0) return
    
    this.currentIndex = (this.currentIndex - 1 + this.currentQueue.length) % this.currentQueue.length
    const prevSong = this.currentQueue[this.currentIndex]
    this.playSongFromQueue(prevSong)
  }

  playSongFromQueue(song) {
    try {
      console.log("playSongFromQueue called with:", song?.title)

      if (!song || !song.url) {
        console.error("Invalid song object in queue");
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

      console.log("Loading track:", song.url)

      // Load and play immediately - no setTimeout delay
      // This keeps the user gesture context alive for mobile Safari
      this.wavesurfer.load(song.url);
      this.wavesurfer.once('ready', () => {
        console.log("Track ready, attempting to play...")

        // Use promise-based play() to handle autoplay blocking
        const playPromise = this.wavesurfer.play();

        // Handle play promise for mobile Safari autoplay restrictions
        if (playPromise !== undefined) {
          playPromise
            .then(() => {
              console.log("Playback started successfully")
            })
            .catch((error) => {
              console.error("Autoplay blocked by browser:", error);
              // Optionally dispatch event to show "Click to continue" UI
              document.dispatchEvent(new CustomEvent("player:autoplay-blocked", {
                detail: { song: song }
              }));
            });
        } else {
          console.log("Play promise undefined - playback should have started")
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
