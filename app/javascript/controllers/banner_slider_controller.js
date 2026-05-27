import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide", "dot"]
  static values = { interval: { type: Number, default: 5000 } }

  connect() {
    this.currentIndex = 0
    this.totalSlides = this.slideTargets.length
    if (this.totalSlides > 1) {
      this.startAutoplay()
    }
    this.showSlide(0)
  }

  disconnect() {
    this.stopAutoplay()
  }

  startAutoplay() {
    this.timer = setInterval(() => this.next(), this.intervalValue)
  }

  stopAutoplay() {
    if (this.timer) clearInterval(this.timer)
  }

  next() {
    const nextIndex = (this.currentIndex + 1) % this.totalSlides
    this.showSlide(nextIndex)
  }

  prev() {
    const prevIndex = (this.currentIndex - 1 + this.totalSlides) % this.totalSlides
    this.showSlide(prevIndex)
  }

  goTo(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.showSlide(index)
  }

  showSlide(index) {
    this.slideTargets.forEach((slide, i) => {
      slide.classList.toggle("opacity-0", i !== index)
      slide.classList.toggle("opacity-100", i === index)
      slide.classList.toggle("z-10", i === index)
      slide.classList.toggle("z-0", i !== index)
    })

    if (this.hasDotTarget) {
      this.dotTargets.forEach((dot, i) => {
        dot.classList.toggle("bg-white", i === index)
        dot.classList.toggle("bg-white/50", i !== index)
      })
    }

    this.currentIndex = index
  }
}
