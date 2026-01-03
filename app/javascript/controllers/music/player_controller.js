import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurfer.js"
import Hls from "hls.js"

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
    waveformUrl: { type: String, default: "" }, // Added for SoundCloud waveforms
  }


  /**
   * Current track URL reference
   * @type {?string}
   */
  currentUrl = null
  isChangingTrack = false

  // ========================
  //  Lifecycle Methods
  // ========================

  /**
   * Initialize controller when connected to DOM
   * Sets up WaveSurfer instance and event listeners
   */
  connect() {
    // Log environment detection for debugging
    const isMobile = this.isMobile();
    const isPWA = this.isPWA();
    console.log(`🎵 PLAYER: Environment detected - Mobile: ${isMobile}, PWA: ${isPWA}`);

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
   * Detect if running as a PWA (installed app)
   * @returns {boolean}
   */
  isPWA() {
    // Check if running in standalone mode (iOS/Android)
    const isStandalone = window.matchMedia('(display-mode: standalone)').matches ||
                         window.navigator.standalone === true

    return isStandalone
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
        backend: backend,
        crossOrigin: "anonymous"
      })

      // Force crossOrigin on the media element
      const media = this.wavesurfer.getMediaElement()
      if (media) {
        media.crossOrigin = "anonymous"
        // Critical for iOS background audio and inline playback
        media.setAttribute("playsinline", "")
        media.setAttribute("webkit-playsinline", "")
      }
      
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
    if (this.isChangingTrack) return;
    
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
   * Smart EQ coordination: Wait for EQ to be ready before playing
   * Uses event-based coordination with timeout fallback to preserve user gesture
   */
  waitForEqualizerThenPlay(playCallback) {
    const isMobileOrPWA = this.isMobile() || this.isPWA()

    // On mobile/PWA: Check if user has enabled EQ
    if (isMobileOrPWA) {
      const mobileEQEnabled = localStorage.getItem("mobileEQEnabled") === "true"

      if (!mobileEQEnabled) {
        console.log("📱 Mobile/PWA: EQ disabled (background playback mode), playing immediately")
        playCallback()
        return
      } else {
        console.log("📱 Mobile/PWA: EQ enabled, waiting for initialization (background playback disabled)")
        // Fall through to desktop EQ logic
      }
    }

    // Desktop: Check if EQ is already connected (from previous track)
    const eqElement = document.querySelector('[data-controller*="music--equalizer"]')
    if (eqElement) {
      const eqController = this.application.getControllerForElementAndIdentifier(
        eqElement,
        "music--equalizer"
      )

      if (eqController?.isConnected) {
        console.log("⚡ EQ already connected, playing immediately")
        playCallback()
        return
      }
    }

    // Desktop or Mobile with EQ enabled: EQ not ready yet, wait for signal with timeout
    const isMobileWithEQ = (this.isMobile() || this.isPWA()) && localStorage.getItem("mobileEQEnabled") === "true"
    const timeout = isMobileWithEQ ? 50 : 100 // Shorter timeout for mobile to preserve gesture

    const deviceType = isMobileWithEQ ? "Mobile/PWA (EQ mode)" : "Desktop"
    console.log(`⏳ ${deviceType}: Waiting for EQ initialization (${timeout}ms timeout)...`)

    let timeoutId
    let handled = false

    const handleReady = () => {
      if (handled) return
      handled = true
      clearTimeout(timeoutId)
      document.removeEventListener('equalizer:ready', handleReady)
      console.log(`✅ ${deviceType}: EQ ready signal received, playing now`)
      playCallback()
    }

    // Listen for EQ ready event
    document.addEventListener('equalizer:ready', handleReady, { once: true })

    // Timeout fallback
    timeoutId = setTimeout(() => {
      if (handled) return
      handled = true
      document.removeEventListener('equalizer:ready', handleReady)
      console.log(`⏰ ${deviceType}: EQ timeout (${timeout}ms), playing anyway`)
      playCallback()
    }, timeout)
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
      const songFromEvent = e.detail;
      // Use a type-insensitive comparison for the ID
      const requestedIndex = this.currentQueue.findIndex(s => String(s.id) === String(songFromEvent.id));

      // If the clicked song is the one currently loaded in the player, just toggle playback.
      if (requestedIndex !== -1 && requestedIndex === this.currentIndex && this.wavesurfer && this.wavesurfer.getMediaElement()) {
        this.togglePlayback();
      } else {
        // Otherwise, it's a new song.
        this.currentIndex = requestedIndex;
        const songToPlay = this.currentQueue[this.currentIndex];
        
        // Determine playOnLoad preference from event or fallback to controller value
        const shouldPlay = songFromEvent.hasOwnProperty('playOnLoad') ? songFromEvent.playOnLoad : this.playOnLoadValue;
        
        if (songToPlay) {
          this.playSongFromQueue(songToPlay, shouldPlay);
        } else {
          // Fallback for safety, if the song wasn't found in the queue.
          this.playSongFromQueue(songFromEvent, shouldPlay);
        }
      }
    } catch (error) {
      console.error("Error handling play event:", error);
      this.handleAudioError();
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
        updateBanner: true,
        playOnLoad: true // Explicitly request play
      }
    }))
  }

  /**
   * Play the next song in queue
   */
  /**
   * Orchestrates waveform peak extraction by detecting the URL format.
   * @param {string} waveformUrl - The URL of the waveform data (.png or .json).
   * @returns {Promise<number[]>} A promise that resolves with an array of normalized peak values.
   */
  /**
   * Orchestrates waveform peak extraction by detecting the URL format.
   * SoundCloud's API can provide either a JSON file with peak data or a PNG
   * image of the waveform. This method handles both cases.
   * @param {string} waveformUrl - The URL of the waveform data (.png or .json).
   * @returns {Promise<number[]>} A promise that resolves with an array of normalized peak values.
   */
  async extractPeaks(waveformUrl) {
    if (!waveformUrl) return [];

    if (waveformUrl.endsWith('.json')) {
      console.log("Waveform URL is JSON, fetching directly.");
      return this._fetchJsonPeaks(waveformUrl);
    } else if (waveformUrl.endsWith('.png')) {
      console.log("Waveform URL is PNG, extracting from image.");
      return this._extractPeaksFromPng(waveformUrl);
    } else {
      console.warn("Unknown waveform URL format:", waveformUrl);
      return [];
    }
  }

  /**
   * Fetches waveform data from a JSON file and normalizes it.
   * @param {string} jsonUrl - The URL of the waveform JSON file.
   * @returns {Promise<number[]>} A promise resolving to an array of normalized peaks.
   */
  async _fetchJsonPeaks(jsonUrl) {
    try {
      const response = await fetch(jsonUrl);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const waveformData = await response.json();
      
      const rawPeaks = waveformData.data || waveformData.samples || [];
      // Defensively filter for only valid numbers.
      const peaks = rawPeaks.filter(p => typeof p === 'number');

      if (peaks.length === 0) return [];

      const maxPeak = Math.max(...peaks);
      // Ensure maxPeak is a valid, finite number before dividing by it.
      if (!isFinite(maxPeak) || maxPeak === 0) {
        return new Array(peaks.length).fill(0);
      }

      const normalizedPeaks = peaks.map(p => p / maxPeak);
      return normalizedPeaks;

    } catch (error) {
      console.error("Failed to fetch or process JSON peaks:", error);
      return [];
    }
  }

  /**
   * Extracts waveform peaks from a SoundCloud PNG image.
   * @param {string} imageUrl - The URL of the waveform PNG image.
   * @returns {Promise<number[]>} A promise that resolves with an array of normalized peak values (0-1).
   */
  async _extractPeaksFromPng(imageUrl) {
    return new Promise((resolve, reject) => {
      if (!imageUrl) {
        return resolve([]); // No image URL, resolve with empty peaks
      }

      const img = new Image();
      img.crossOrigin = 'anonymous'; // Important for CORS if image is on different domain
      img.onload = () => {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = img.width;
        canvas.height = img.height;
        ctx.drawImage(img, 0, 0);

        const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        const data = imageData.data;
        const peaks = [];
        const totalColumns = canvas.width;
        const halfHeight = canvas.height / 2; // Waveform usually symmetric around center

        for (let i = 0; i < totalColumns; i++) {
          let topY = halfHeight; // Start from center, go up
          let bottomY = halfHeight; // Start from center, go down
          let foundTop = false;
          let foundBottom = false;

          // Scan upwards from center for the top edge of the waveform
          for (let y = halfHeight; y >= 0; y--) {
            const alpha = data[((y * totalColumns + i) * 4) + 3];
            if (alpha > 0) {
              topY = y;
              foundTop = true;
              break;
            }
          }

          // Scan downwards from center for the bottom edge of the waveform
          for (let y = halfHeight; y < canvas.height; y++) {
            const alpha = data[((y * totalColumns + i) * 4) + 3];
            if (alpha > 0) {
              bottomY = y;
              foundBottom = true;
              break;
            }
          }
          
          let peakValue = 0;
          if (foundTop && foundBottom) {
              const topDeviation = halfHeight - topY;
              const bottomDeviation = bottomY - halfHeight;
              peakValue = Math.max(topDeviation, bottomDeviation) / halfHeight;
          }
          peaks.push(peakValue);
        }
        resolve(peaks);
      };
      img.onerror = (e) => {
        console.error("Error loading waveform image:", imageUrl, e);
        reject(e); // Reject with the error event
      };
      img.src = imageUrl;
    });
  }

  /**
   * Resamples an array of peaks to a new, desired length. This is the core
   * logic to ensure pre-computed waveforms look consistent with analyzed ones.
   * - Down-samples by finding the maximum peak in each segment to preserve spikiness.
   * - Up-samples by using linear interpolation to create smooth transitions.
   * @param {number[]} peaks - The original array of peak data.
   * @param {number} newLength - The desired length for the new array.
   * @returns {number[]} The resampled array of peaks.
   */
  _resamplePeaks(peaks, newLength) {
    if (!Array.isArray(peaks) || peaks.length === 0 || newLength <= 0) {
      return [];
    }

    if (peaks.length === newLength) {
      return peaks;
    }

    const newPeaks = new Array(newLength);
    
    // Down-sampling (find max peak in segment)
    if (peaks.length > newLength) {
      const factor = peaks.length / newLength;
      for (let i = 0; i < newLength; i++) {
        const start = Math.floor(i * factor);
        const end = Math.floor((i + 1) * factor);
        let max = 0;
        for (let j = start; j < end; j++) {
          // Ensure peak is a valid number before comparison
          if (typeof peaks[j] === 'number' && peaks[j] > max) {
            max = peaks[j];
          }
        }
        newPeaks[i] = max;
      }
      return newPeaks;
    } 
    // Up-sampling (interpolating)
    else {
      const spring = (peaks.length - 1) / (newLength - 1);
      newPeaks[0] = Number(peaks[0]) || 0;
      newPeaks[newLength - 1] = Number(peaks[peaks.length - 1]) || 0;

      for (let i = 1; i < newLength - 1; i++) {
        const index = i * spring;
        const i_lo = Math.floor(index);
        const i_hi = Math.ceil(index);
        
        // Ensure peaks are numbers, default to 0 if not
        const p_lo = Number(peaks[i_lo]) || 0;
        const p_hi = Number(peaks[i_hi]) || 0;
        
        const weight = index - i_lo;
        newPeaks[i] = p_lo * (1 - weight) + p_hi * weight;
      }
      return newPeaks;
    }
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
    this.playSongFromQueue(nextSong, true); // Force play for auto-advance
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
    this.playSongFromQueue(prevSong, true) // Force play for previous button
  }

  async playSongFromQueue(song, playOnLoad = this.playOnLoadValue) {
    try {
      this.isChangingTrack = true;

      // If the song is from SoundCloud, refresh its data to get a fresh stream URL
      if (song.audioSource === 'SoundCloud') {
        console.log("🔄 Refreshing SoundCloud track:", song.title);
        try {
          const response = await fetch(`/zuke/refresh_soundcloud_track/${song.id}`);
          if (response.ok) {
            const refreshedSongData = await response.json();
            console.log("✅ Refreshed data received:", refreshedSongData);
            // Update the song object with the fresh data
            Object.assign(song, refreshedSongData);

            // Also update the song in the main queue
            const songInQueue = this.currentQueue.find(s => s.id === song.id);
            if (songInQueue) {
              Object.assign(songInQueue, refreshedSongData);
            }
          } else {
            console.error("❌ Failed to refresh SoundCloud track. Status:", response.status);
            // Proceed with the potentially expired URL, it might still work.
          }
        } catch (error) {
          console.error("❌ Error refreshing SoundCloud track:", error);
        }
      }

      // Destroy previous HLS instance if it exists. This is crucial to prevent
      // the old HLS instance from interfering with the playback of subsequent
      // tracks, especially non-HLS local files.
      if (this.hls) {
        console.log("Destroying previous HLS instance.");
        this.hls.destroy();
        this.hls = null;
      }

      console.log("🎵 playSongFromQueue() called with:", song?.title, "playOnLoad:", playOnLoad)

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

      // Dispatch track change event
      this.dispatchTrackChange(song);

      console.log("📥 Loading track:", song.title, "URL:", song.url.substring(0, 80) + "...")

      // Shared playback logic
      const attemptPlayback = () => {
        if (playOnLoad) {
          console.log("✅ Play on load is active. Attempting to play...");
          const playPromise = this.wavesurfer.play();
          if (playPromise !== undefined) {
            playPromise.then(() => {
              this.isChangingTrack = false;
            }).catch((error) => {
              console.error("🚫 Autoplay blocked by browser or failed:", error);
              this.isChangingTrack = false;
              document.dispatchEvent(new CustomEvent("player:autoplay-blocked", { detail: { song, error } }));
            });
          } else {
            this.isChangingTrack = false;
          }
        } else {
           console.log("⏸️ Play on load is inactive. Waiting for user interaction.");
           this.isChangingTrack = false;
        }
      };
      
      const setupReadyListener = () => {
        this.wavesurfer.once('ready', () => {
          console.log("✅ Track ready, checking playback preference...");

          // CRITICAL: Wait for EQ to be ready, but use smart timing to preserve user gesture
          // - On first track: EQ needs ~50ms to build audio graph
          // - On subsequent tracks: EQ is already built, just loads settings
          // - In PWA/mobile: Use shorter timeout (30ms) to preserve gesture chain
          // - In desktop: Use longer timeout (100ms) for safety
          this.waitForEqualizerThenPlay(attemptPlayback);
        });
      };

      // Conditional HLS loading for SoundCloud
      if (song.audioSource === 'SoundCloud' && Hls.isSupported()) {
        // The loading process for HLS tracks with pre-computed peaks is sensitive
        // to the order of operations to avoid race conditions between Wavesurfer and HLS.js.
        // The correct sequence is:
        // 1. Get raw peaks from the SoundCloud API (JSON or PNG).
        // 2. Resample peaks to match the density required by the player's settings.
        // 3. Load the resampled peaks into Wavesurfer with the empty media element.
        // 4. Attach HLS.js to the media element and load the stream source.
        // 5. Play the audio only after the HLS manifest has been parsed.
        console.log("HLS stream detected, using global Hls object.");
        
        // 1. Get raw peaks first
        const rawPeaks = song.waveformUrl ? await this.extractPeaks(song.waveformUrl) : [];
        
        // 2. Resample peaks to match the density defined by minPxPerSec
        const minPxPerSec = this.wavesurfer.options.minPxPerSec || 50;
        const barWidth = this.wavesurfer.options.barWidth || 2;
        const barGap = this.wavesurfer.options.barGap || 1;
        const totalWidth = song.duration * minPxPerSec;
        const numBars = Math.floor(totalWidth / (barWidth + barGap));
        
        console.log(`Resampling peaks: original ${rawPeaks.length}, target bars ${numBars} for duration ${song.duration}s`);
        const peaks = this._resamplePeaks(rawPeaks, numBars);

        // 3. Load peaks into wavesurfer with the empty media element
        if (this.wavesurfer && peaks.length > 0) {
          this.wavesurfer.load(this.wavesurfer.getMediaElement(), peaks, song.duration);
          console.log(`Peaks loaded and resampled from ${rawPeaks.length} to ${peaks.length} points.`);
        } else if (this.wavesurfer) {
          console.warn("No peaks extracted or waveformUrl was empty.");
        }
        
        // 4. Set up HLS
        const hls = new Hls();
        hls.loadSource(song.url);
        hls.attachMedia(this.wavesurfer.getMediaElement());
        this.hls = hls;

        // 5. Play when HLS is ready
        hls.on(Hls.Events.MANIFEST_PARSED, () => {
          console.log("✅ HLS manifest parsed, checking playback preference...");

          // Use smart EQ coordination for HLS tracks too
          this.waitForEqualizerThenPlay(attemptPlayback);
        });
      } else {
        // Logic for local files with pre-computed waveforms
        if (song.waveformUrl) {
          console.log("Local file with waveformUrl detected.");
          
          // 1. Get raw peaks from our own JSON file
          const rawPeaks = await this._fetchJsonPeaks(song.waveformUrl);

          // 2. Resample peaks to match the density defined by minPxPerSec
          let peaks = rawPeaks;
          if (song.duration && song.duration > 0) {
            const minPxPerSec = this.wavesurfer.options.minPxPerSec || 50;
            const barWidth = this.wavesurfer.options.barWidth || 2;
            const barGap = this.wavesurfer.options.barGap || 1;
            const totalWidth = song.duration * minPxPerSec;
            const numBars = Math.floor(totalWidth / (barWidth + barGap));
            
            console.log(`Resampling peaks for local file: original ${rawPeaks.length}, target bars ${numBars} for duration ${song.duration}s`);
            peaks = this._resamplePeaks(rawPeaks, numBars);
          } else {
            console.warn("Song duration is 0 or missing, using raw peaks without resampling.");
          }

          // 3. Load audio URL with pre-computed peaks
          // Setup listener strictly before loading but AFTER async fetch
          setupReadyListener();
          // Use undefined for duration if it's 0 so WaveSurfer can auto-detect from media
          this.wavesurfer.load(song.url, peaks, song.duration || undefined);

        } else {
          // Fallback for local files without a waveform (e.g., old files)
          console.log("Local file without waveformUrl, loading directly.");
          setupReadyListener();
          this.wavesurfer.load(song.url);
        }
      }
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
  dispatchTrackChange(song) {
    this.currentUrl = song.url
    window.dispatchEvent(new CustomEvent("audio:changed", { detail: { url: song.url, id: song.id } }))
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
