// app/javascript/controllers/smart_image_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["playButton"]
  static values = {
    id: String,
    url: String,
    title: String,
    artist: String,
    banner: String,
    bannerMobile: String,
    bannerVideo: String,
    imageCredit: String,
    imageCreditUrl: String,
    imageLicense: String,
    audioSource: String,
    audioLicense: String,
    additionalCredits: String,
    waveformUrl: String, // Add waveformUrl
    duration: Number,    // Add duration
  }

  connect() {
    // Only keep track of current song
    window.addEventListener("audio:changed", this.handleSongChange.bind(this))
    window.addEventListener("player:state:changed", this.handleStateChange.bind(this))
    
    this.isSelected = false
    this.isPlaying = false
  }

  disconnect() {
    window.removeEventListener("audio:changed", this.handleSongChange)
    window.removeEventListener("player:state:changed", this.handleStateChange)
  }

  playRequest(e) {
    e.preventDefault()
    const playOnLoad = localStorage.getItem("audioPlayOnLoad") === "true"
    const updateBanner = true

    window.dispatchEvent(new CustomEvent("player:play-requested", {
      detail: {
        id: this.idValue,
        url: this.urlValue,
        title: this.titleValue,
        artist: this.artistValue,
        banner: this.bannerValue,
        bannerMobile: this.bannerMobileValue,
        bannerVideo: this.bannerVideoValue,
        playOnLoad: playOnLoad,
        updateBanner: updateBanner,
        imageCredit: this.imageCreditValue,
        imageCreditUrl: this.imageCreditUrlValue,
        imageLicense: this.imageLicenseValue,
        audioSource: this.audioSourceValue,
        audioLicense: this.audioLicenseValue,
        additionalCredits: this.additionalCreditsValue,
        waveformUrl: this.waveformUrlValue, // Pass waveformUrl
        duration: this.durationValue,       // Pass duration
      }
    }))

    this.currentUrl = this.urlValue
  }


  handleSongChange(e) {
    // Coerce both IDs to strings for a reliable comparison
    this.isSelected = String(e.detail.id) === this.idValue
    
    // When song changes, playing state usually resets or we wait for state change
    // But we should update appearance immediately to show selection if needed
    // Note: The player might not have fired 'playing' yet for the new song
    this.updateAppearance()
  }

  handleStateChange(e) {
    this.isPlaying = e.detail.playing
    this.updateAppearance()
  }

  updateAppearance() {
    if (!this.hasPlayButtonTarget) return

    if (this.isSelected && this.isPlaying) {
      this.playButtonTarget.classList.add("border-lime-500")
    } else {
      this.playButtonTarget.classList.remove("border-lime-500")
    }
  }
}
