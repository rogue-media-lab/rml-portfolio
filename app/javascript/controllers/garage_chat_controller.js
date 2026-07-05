import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "messages", "button"]
  static values = { chatUrl: String }

  connect() {
    this._sending = false
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submit()
    }
  }

  async submit() {
    const content = this.inputTarget.value.trim()
    if (!content || this._sending) return

    this._sending = true
    this.inputTarget.value = ""
    this.buttonTarget.disabled = true

    // Append user message
    this._appendUserMessage(content)

    // Append loading bubble
    const loadingBubble = this._appendLoadingBubble()

    try {
      const response = await fetch(this.chatUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this._csrfToken()
        },
        body: JSON.stringify({ content })
      })

      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const data = await response.json()

      // Remove loading bubble
      loadingBubble.remove()

      // Append assistant reply
      this._appendAssistantMessage(data.reply)

    } catch (error) {
      loadingBubble.remove()
      this._appendAssistantMessage("I'm having trouble connecting. Try again in a moment.")
    } finally {
      this._sending = false
      this.buttonTarget.disabled = false
      this.inputTarget.focus()
    }

    this._scrollToBottom()
  }

  _appendUserMessage(content) {
    const el = document.createElement("div")
    el.className = "flex justify-end"
    el.innerHTML = `
      <div class="rounded-2xl rounded-tr-sm bg-carus-green px-4 py-3 max-w-[240px]">
        <p class="text-[14px]/[20px] font-medium text-black">${this._escapeHtml(content)}</p>
      </div>
    `
    this.messagesTarget.appendChild(el)
    this._scrollToBottom()
  }

  _appendLoadingBubble() {
    const el = document.createElement("div")
    el.className = "flex gap-2.5"
    el.innerHTML = `
      <div class="shrink-0 size-7 rounded-full bg-carus-field mt-0.5"></div>
      <div class="flex flex-col gap-1 max-w-[265px]">
        <div class="rounded-2xl rounded-tl-sm bg-carus-panel border border-[#FFFFFF08] px-4 py-3">
          <p class="text-[13px]/[19px] font-medium text-white opacity-40">...</p>
        </div>
      </div>
    `
    this.messagesTarget.appendChild(el)
    this._scrollToBottom()
    return el
  }

  _appendAssistantMessage(content) {
    const el = document.createElement("div")
    el.className = "flex gap-2.5"
    el.innerHTML = `
      <div class="shrink-0 size-7 rounded-full bg-carus-field mt-0.5"></div>
      <div class="flex flex-col gap-1 max-w-[265px]">
        <div class="rounded-2xl rounded-tl-sm bg-carus-panel border border-[#FFFFFF08] px-4 py-3">
          <p class="text-[13px]/[19px] font-medium text-white">${this._escapeHtml(content)}</p>
        </div>
      </div>
    `
    this.messagesTarget.appendChild(el)
    this._scrollToBottom()
  }

  _scrollToBottom() {
    window.requestAnimationFrame(() => {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    })
  }

  _escapeHtml(text) {
    const div = document.createElement("div")
    div.appendChild(document.createTextNode(text))
    return div.innerHTML
  }

  _csrfToken() {
    return document.querySelector('[name="csrf-token"]')?.content || ""
  }
}