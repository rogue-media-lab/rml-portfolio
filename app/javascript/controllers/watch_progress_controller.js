import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    videoId: Number,
    progressUrl: String,
    currentProgress: { type: Number, default: 0 }
  }

  connect() {
    this.player = null
    this.saveInterval = null
    this.pollInterval = null
    this.isReady = false

    if (window.YT && window.YT.Player) {
      this.initPlayer()
    } else {
      window.onYouTubeIframeAPIReady = () => this.initPlayer()
    }
  }

  disconnect() {
    this.stopSaving()
    if (this.player) {
      try { this.player.destroy() } catch (e) {}
    }
  }

  initPlayer() {
    const iframe = this.element.querySelector("iframe")
    if (!iframe) return

    this.player = new YT.Player(iframe, {
      events: {
        onReady: (event) => this.onPlayerReady(event),
        onStateChange: (event) => this.onPlayerStateChange(event)
      }
    })
  }

  onPlayerReady(event) {
    this.isReady = true
    if (this.currentProgressValue > 0) {
      try {
        this.player.seekTo(this.currentProgressValue, true)
      } catch (e) {}
    }
  }

  onPlayerStateChange(event) {
    if (event.data === YT.PlayerState.PLAYING) {
      this.startSaving()
    } else if (event.data === YT.PlayerState.PAUSED || event.data === YT.PlayerState.ENDED) {
      this.saveProgress()
      this.stopSaving()
    }
  }

  startSaving() {
    if (this.saveInterval) return
    this.saveInterval = setInterval(() => this.saveProgress(), 5000)
  }

  stopSaving() {
    if (this.saveInterval) {
      clearInterval(this.saveInterval)
      this.saveInterval = null
    }
  }

  saveProgress() {
    if (!this.isReady || !this.player) return

    try {
      const currentTime = Math.floor(this.player.getCurrentTime())
      const duration = Math.floor(this.player.getDuration())
      const isCompleted = duration > 0 && currentTime / duration >= 0.9

      const payload = {
        watch_progress: {
          progress_seconds: currentTime,
          completed: isCompleted
        }
      }

      const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

      fetch(this.progressUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken || ""
        },
        body: JSON.stringify(payload)
      }).catch(() => {})
    } catch (e) {}
  }
}
