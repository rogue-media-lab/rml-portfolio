// app/javascript/controllers/music/banner_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "video", "title", "subtitle"]

  connect() {
    document.addEventListener("music:banner:update", this.updateBanner.bind(this))
    window.addEventListener("music:banner:video-preference", this.handleVideoPreference.bind(this))
    window.addEventListener("audio:ready", this.handleAudioReady.bind(this))

    // Load initial video preference
    const videoEnabled = localStorage.getItem("bannerVideoEnabled") === "true"
    this.videoEnabled = videoEnabled
  }

  disconnect() {
    document.removeEventListener("music:banner:update", this.updateBanner.bind(this))
    window.removeEventListener("music:banner:video-preference", this.handleVideoPreference.bind(this))
    window.removeEventListener("audio:ready", this.handleAudioReady.bind(this))
  }

  handleVideoPreference(event) {
    this.videoEnabled = event.detail.enabled
    this.updateMediaDisplay()
  }

  updateBanner(event) {
    const { image, imageMobile, video, title, subtitle } = event.detail

    // Store current media URLs
    this.currentImage = image
    this.currentImageMobile = imageMobile
    this.currentVideo = video
    this.pendingVideoUrl = video // Store for later loading
    this.videoLoaded = false // Reset video loaded state

    // If no video for this song, clear the video element
    if (!video && this.hasVideoTarget) {
      this.videoTarget.src = ""
      this.videoTarget.load() // Force clear
    }

    // Choose the appropriate image based on device type (not just screen width)
    // Check for mobile device using multiple signals
    const isMobileDevice = this.isMobileDevice()
    const selectedImage = (isMobileDevice && imageMobile) ? imageMobile : (image || null)

    // Always update image if we have a valid URL and it's different
    if (selectedImage && selectedImage !== '') {
      // Check if image actually needs updating
      const needsUpdate = !this.imageTarget.src || !this.imageTarget.src.endsWith(selectedImage.split('/').pop())

      if (needsUpdate) {
        // Update image src directly (no transition for snappier feel)
        this.imageTarget.src = selectedImage;

        // Ensure image is visible and has opacity
        this.imageTarget.style.opacity = 0;

        // Show image when loaded
        this.imageTarget.onload = () => {
          this.imageTarget.style.opacity = 1;
          this.imageTarget.onload = null; // Clean up
        };

        // Fallback in case onload doesn't fire
        setTimeout(() => {
          if (this.imageTarget.complete) {
            this.imageTarget.style.opacity = 1;
          }
        }, 300);
      } else {
        // Same image, just ensure it's visible
        this.imageTarget.style.opacity = 1;
      }
    }

    // DON'T load video yet - wait for audio:ready event
    // This prevents video from competing with audio for bandwidth

    // Update media display based on preference
    this.updateMediaDisplay()

    if (title) this.titleTarget.textContent = title;
    if (subtitle) this.subtitleTarget.textContent = subtitle;
  }

  handleAudioReady(event) {
    // Audio is ready and decoded - NOW it's safe to load video
    if (this.pendingVideoUrl && this.hasVideoTarget && !this.videoLoaded) {
      console.log("Audio ready - loading video now")
      this.videoTarget.src = this.pendingVideoUrl
      this.videoTarget.load()
      this.videoLoaded = true
    }
  }

  updateMediaDisplay() {
    // Show video if enabled, video is available, and video target exists
    const showVideo = this.videoEnabled && this.currentVideo && this.hasVideoTarget

    if (this.hasVideoTarget) {
      if (showVideo) {
        this.videoTarget.classList.remove("hidden")
        this.imageTarget.classList.add("hidden")
      } else {
        this.videoTarget.classList.add("hidden")
        this.imageTarget.classList.remove("hidden")
        // Ensure image is visible when showing it
        this.imageTarget.style.opacity = 1
      }
    } else {
      // No video target at all, ensure image is visible
      this.imageTarget.classList.remove("hidden")
      this.imageTarget.style.opacity = 1
    }
  }

  /**
   * Detect if running on mobile device
   * Uses multiple detection methods for better accuracy
   * @returns {boolean}
   */
  isMobileDevice() {
    // Check user agent for mobile devices
    const mobileUA = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)

    // Check for touch support (primary indicator)
    const isTouchDevice = ('ontouchstart' in window) || (navigator.maxTouchPoints > 0)

    // Return true if either mobile UA or touch device
    // This ensures mobile detection works even in fullscreen landscape mode
    return mobileUA || isTouchDevice
  }
}
