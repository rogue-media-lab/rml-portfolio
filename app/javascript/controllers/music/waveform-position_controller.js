// app/javascript/controllers/music/waveform-position_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    console.log("Waveform position controller connected")
    // Listen for banner height changes
    window.addEventListener("music:banner:height-changed", this.handleBannerHeightChange.bind(this))
  }

  disconnect() {
    window.removeEventListener("music:banner:height-changed", this.handleBannerHeightChange.bind(this))
  }

  handleBannerHeightChange(event) {
    const { expanded } = event.detail

    if (expanded) {
      this.positionOverBanner()
    } else {
      this.positionBelowBanner()
    }
  }

  positionOverBanner() {
    // Position waveform on top of banner with semi-transparent background
    this.containerTarget.classList.remove("relative", "bg-black")
    this.containerTarget.classList.add("absolute", "z-30", "bg-[linear-gradient(to_right,rgba(0,0,0,0.5),transparent)]", "backdrop-blur-sm")
    // Position below title/artist (title/artist are centered, so place waveform at ~60% from top)
    this.containerTarget.style.top = "55%"
    this.containerTarget.style.left = "0"
    this.containerTarget.style.right = "0"
    this.containerTarget.style.transform = "translateY(0)"
  }

  positionBelowBanner() {
    // Position waveform below banner with solid background
    this.containerTarget.classList.remove("absolute", "z-30", "bg-black/70", "backdrop-blur-sm")
    this.containerTarget.classList.add("relative", "bg-black")
    // Reset inline styles
    this.containerTarget.style.top = ""
    this.containerTarget.style.left = ""
    this.containerTarget.style.right = ""
    this.containerTarget.style.transform = ""
  }
}
