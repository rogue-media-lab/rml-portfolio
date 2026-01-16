import { Controller } from "@hotwired/stimulus"

// Handles form submission states for Hermit Plus contact form
export default class extends Controller {
  static targets = ["submit", "form"]

  connect() {
    this.originalSubmitText = this.submitTarget.innerHTML
  }

  submit(event) {
    // Show loading state
    this.submitTarget.disabled = true
    this.submitTarget.classList.add("opacity-70", "cursor-not-allowed")
    this.submitTarget.innerHTML = "Sending..."
  }

  // Called on successful form submission
  success() {
    this.submitTarget.innerHTML = "Sent!"
    this.submitTarget.classList.remove("bg-hermit-teal", "hover:bg-hermit-teal/90")
    this.submitTarget.classList.add("bg-green-600")

    // Reset form
    this.formTarget.reset()

    // Reset button after 3 seconds
    setTimeout(() => {
      this.resetButton()
    }, 3000)
  }

  // Called on form submission error
  error() {
    this.submitTarget.innerHTML = "Error - Try Again"
    this.submitTarget.classList.remove("bg-hermit-teal")
    this.submitTarget.classList.add("bg-red-600")
    this.submitTarget.disabled = false
    this.submitTarget.classList.remove("opacity-70", "cursor-not-allowed")

    // Reset button after 3 seconds
    setTimeout(() => {
      this.resetButton()
    }, 3000)
  }

  resetButton() {
    this.submitTarget.disabled = false
    this.submitTarget.classList.remove("opacity-70", "cursor-not-allowed", "bg-green-600", "bg-red-600")
    this.submitTarget.classList.add("bg-hermit-teal", "hover:bg-hermit-teal/90")
    this.submitTarget.innerHTML = this.originalSubmitText
  }
}
