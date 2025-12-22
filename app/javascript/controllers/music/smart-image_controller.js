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
  }

  disconnect() {
    window.removeEventListener("audio:changed", this.handleSongChange)
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
    // If this smart image doesn't have a target, do nothing.
    if (!this.hasPlayButtonTarget) return;

    // Coerce both IDs to strings for a reliable comparison,
    // as the event detail ID might be a number (for local tracks) while the
    // value on the controller is always a string.
    if (String(e.detail.id) === this.idValue) {
      this.playButtonTarget.classList.add("border-lime-500")
    } else {
      this.playButtonTarget.classList.remove("border-lime-500")
    }
  }
}
