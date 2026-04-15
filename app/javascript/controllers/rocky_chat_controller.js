import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["messages", "input", "sendButton", "persistedAssistant"]
  static values = {
    sessionId:           String,
    messagesUrl:         String,
    ttsUrl:              String,
    toneMatchUrl:        String,
    generateImageUrl:    String,
    generateVideoUrl:    String,
    generateMusicUrl:    String
  }

  connect() {
    this.currentAudio    = null
    this._streaming      = false
    this._toneQueue      = []
    this._tonePlaying    = false
    this._ttsReady       = false
    this._tonePending    = false
    this._audioCtx       = null
    this._reverbNode     = null
    this._currentTtsSrc  = null
    this._videoSubscription = null

    // Render persisted assistant messages through the same formatter
    this.persistedAssistantTargets.forEach(el => {
      const raw = el.dataset.rawContent || ""
      if (raw.trim()) el.innerHTML = this.formatContent(raw)
    })

    // Subscribe to video status channel so background jobs can push completed videos
    if (this.hasSessionIdValue && this.sessionIdValue) {
      this._subscribeVideoChannel()
    }

    this.scrollToBottom()
    this.inputTarget.focus()
  }

  disconnect() {
    if (this._videoSubscription) {
      this._videoSubscription.unsubscribe()
      this._videoSubscription = null
    }
  }

  _subscribeVideoChannel() {
    const sessionId = this.sessionIdValue
    this._videoSubscription = consumer.subscriptions.create(
      { channel: "Rocky::VideoStatusChannel", chat_session_id: sessionId },
      {
        received: (data) => this._handleVideoReady(data)
      }
    )
  }

  _handleVideoReady(data) {
    const placeholder = this.messagesTarget.querySelector(
      `[data-video-pending][data-message-id="${data.message_id}"]`
    )
    if (!placeholder) return

    if (data.status === "ready" && data.url) {
      const mediaEl = document.createElement("div")
      mediaEl.className = "message__media mt-2"
      mediaEl.innerHTML = `<video src="${data.url}" controls class="media-result--video"></video>`
      placeholder.replaceWith(mediaEl)
    } else if (data.status === "error") {
      placeholder.textContent = "Problem! Video failed to generate."
      placeholder.classList.remove("tone-marker")
    }
  }

  // ── Input handling ────────────────────────────────────────────────────────

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submit(event)
    }
  }

  autoResize() {
    const el = this.inputTarget
    el.style.height = "auto"
    el.style.height = Math.min(el.scrollHeight, 160) + "px"
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  async submit(event) {
    if (event) event.preventDefault()

    const content = this.inputTarget.value.trim()
    if (!content || this._streaming) return

    // Slash commands
    if (content.startsWith("/image ")) {
      return this.generateMedia("image", content.slice(7).trim())
    }
    if (content.startsWith("/video ")) {
      return this.generateMedia("video", content.slice(7).trim())
    }
    if (content.startsWith("/music ")) {
      return this.generateMedia("music", content.slice(7).trim())
    }

    this.inputTarget.value = ""
    this.inputTarget.style.height = "auto"
    this._setStreaming(true)

    this.appendUserMessage(content)
    const assistantBubble = this.appendAssistantBubble()

    try {
      const response = await fetch(this.messagesUrlValue, {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token":  this.csrfToken
        },
        body: JSON.stringify({ content })
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      await this._consumeSSE(response, assistantBubble)

    } catch (error) {
      console.error("Rocky chat error:", error)
      this._updateBubble(assistantBubble, "Problem! Connection lost. Try again.")
    } finally {
      this._setStreaming(false)
      this.inputTarget.focus()
    }
  }

  // ── SSE streaming ─────────────────────────────────────────────────────────

  async _consumeSSE(response, bubble) {
    // Reset tone/TTS gate for this response
    this._toneQueue   = []
    this._tonePlaying = false
    this._ttsReady    = false
    this._tonePending = false

    const reader  = response.body.getReader()
    const decoder = new TextDecoder()
    let buffer      = ""
    let fullContent = ""
    const playedTones = new Set()

    while (true) {
      const { value, done } = await reader.read()
      if (done) break

      buffer += decoder.decode(value, { stream: true })
      const lines = buffer.split("\n")
      buffer = lines.pop() // keep incomplete trailing line

      for (const line of lines) {
        if (!line.startsWith("data: ")) continue

        let data
        try {
          data = JSON.parse(line.slice(6))
        } catch {
          continue
        }

        if (data.type === "content") {
          fullContent += data.delta
          this._updateBubble(bubble, fullContent)
          this.scrollToBottom()
          this._playNewTones(fullContent, playedTones)

        } else if (data.type === "tool_call") {
          const label = { generate_image: "image", generate_video: "video", generate_music: "music" }[data.tool] || data.tool
          // Show status in bubble without adding to fullContent — keeps TTS clean
          const contentEl = bubble.querySelector("[data-content]")
          if (contentEl) {
            const hint = document.createElement("span")
            hint.className = "tone-marker block mt-1"
            hint.dataset.generatingHint = "true"
            hint.textContent = `♪ generating ${label}…`
            contentEl.appendChild(hint)
          }
          this.scrollToBottom()

        } else if (data.type === "video_pending") {
          // Video job enqueued — insert a placeholder that the cable broadcast will replace
          bubble.querySelectorAll("[data-generating-hint]").forEach(el => el.remove())
          const body = bubble.querySelector(".message__body") || bubble
          const pending = document.createElement("div")
          pending.className = "tone-marker mt-2"
          pending.dataset.videoPending = "true"
          pending.dataset.messageId = data.message_id
          pending.textContent = "♪ video processing… will appear when ready"
          body.appendChild(pending)
          this.scrollToBottom()

        } else if (data.type === "media") {
          // Remove the "generating…" hint before showing the real media
          bubble.querySelectorAll("[data-generating-hint]").forEach(el => el.remove())
          this.appendMediaToBubble(bubble, data.media_type, data.url)
          this.scrollToBottom()

        } else if (data.type === "done") {
          const speakText = this.stripToneMarkers(fullContent)
          if (speakText.trim()) this.speakText(speakText)

        } else if (data.type === "error") {
          this._updateBubble(bubble, "Problem! Rocky not responding. Try again.")
        }
      }
    }
  }

  // ── Tone playback ─────────────────────────────────────────────────────────

  _playNewTones(fullContent, playedSet) {
    if (!this.hasToneMatchUrlValue) return

    const TONE_RE = /\*🎵\s*(.*?)\s*🎵\*/g
    let match
    while ((match = TONE_RE.exec(fullContent)) !== null) {
      const description = match[1].trim()
      if (!playedSet.has(description)) {
        playedSet.add(description)
        this._fetchAndPlayTone(description)
      }
    }
  }

  async _fetchAndPlayTone(description) {
    try {
      const url = `${this.toneMatchUrlValue}?description=${encodeURIComponent(description)}`
      const response = await fetch(url)
      if (!response.ok) return

      const blob = await response.blob()
      if (!blob.size) return

      const audioUrl = URL.createObjectURL(blob)
      this._toneQueue.push(audioUrl)
      if (!this._tonePlaying) this._drainToneQueue()
    } catch (e) {
      // Tone fetch failure is non-critical
    }
  }

  _drainToneQueue() {
    if (this._toneQueue.length === 0) {
      this._tonePlaying = false
      return
    }

    // Hold until TTS has started — tones play in background behind Rocky's voice
    if (!this._ttsReady) {
      this._tonePending = true
      this._tonePlaying = false
      return
    }

    this._tonePlaying = true
    const audioUrl = this._toneQueue.shift()
    const audio = new Audio(audioUrl)
    audio.volume = 0.3
    audio.play()
    audio.addEventListener("ended", () => {
      URL.revokeObjectURL(audioUrl)
      this._drainToneQueue()
    })
  }

  // Called when TTS starts (or fails) — releases any queued tones
  _releaseToneQueue() {
    this._ttsReady = true
    if (this._tonePending) {
      this._tonePending = false
      this._drainToneQueue()
    }
  }

  // ── Content formatting ────────────────────────────────────────────────────

  formatContent(text) {
    return text
      .replace(/\*🎵\s*(.*?)\s*🎵\*/g, '<span class="tone-marker">♪ $1</span>')
      .replace(/\n/g, "<br>")
  }

  stripToneMarkers(text) {
    return text
      .replace(/\*🎵\s*.*?\s*🎵\*/g, "")
      .replace(/\s+/g, " ")
      .trim()
  }

  // ── Bubble helpers ────────────────────────────────────────────────────────

  _updateBubble(bubble, fullText) {
    const contentEl = bubble.querySelector("[data-content]")
    if (contentEl) contentEl.innerHTML = this.formatContent(fullText)
  }

  appendUserMessage(content) {
    const el = document.createElement("div")
    el.className = "message message--user"
    el.innerHTML = `<div class="message__content" data-content>${this.escapeHtml(content)}</div>`
    this.messagesTarget.appendChild(el)
    this.scrollToBottom()
    return el
  }

  appendAssistantBubble() {
    const el = document.createElement("div")
    el.className = "message message--assistant"
    el.innerHTML = `
      <div class="message__avatar">R</div>
      <div class="message__body">
        <div class="message__content" data-content>
          <span class="tone-marker" style="opacity:0.5;">♪ thinking…</span>
        </div>
        <button class="message__speak-btn" data-action="click->rocky-chat#speakMessage">
          ♪ Speak
        </button>
      </div>
    `
    this.messagesTarget.appendChild(el)
    this.scrollToBottom()
    return el
  }

  // ── Media generation ──────────────────────────────────────────────────────

  async generateMedia(type, prompt) {
    if (this._streaming) return
    this.inputTarget.value = ""
    this.inputTarget.style.height = "auto"
    this._setStreaming(true)

    this.appendUserMessage(`/${type} ${prompt}`)

    const urlMap = {
      image: this.generateImageUrlValue,
      video: this.generateVideoUrlValue,
      music: this.generateMusicUrlValue
    }

    const loadingBubble = this.appendAssistantBubble()
    this._updateBubble(loadingBubble, `*🎵 focused hum 🎵* Generating ${type}… hold on.`)

    try {
      const body = { prompt }
      if (this.hasSessionIdValue) body.session_id = this.sessionIdValue

      const response = await fetch(urlMap[type], {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token":  this.csrfToken
        },
        body: JSON.stringify(body)
      })

      const data = await response.json()

      if (data.pending) {
        // Video is generating in the background — insert a placeholder
        this._updateBubble(loadingBubble, `*🎵 focused hum 🎵* Video processing. Will appear when ready.`)
        const bubbleBody = loadingBubble.querySelector(".message__body") || loadingBubble
        const pending = document.createElement("div")
        pending.className = "tone-marker mt-2"
        pending.dataset.videoPending = "true"
        pending.dataset.messageId = data.message_id
        pending.textContent = "♪ video processing… will appear when ready"
        bubbleBody.appendChild(pending)
      } else if (data.url) {
        this._updateBubble(loadingBubble, `*🎵 pleased hum 🎵* Is done! Amaze!`)
        this.appendMedia(type, data.url)
      } else {
        this._updateBubble(loadingBubble, `Problem! ${data.error || "Generation failed."}`)
      }
    } catch (e) {
      console.error("Rocky generate error:", e)
      this._updateBubble(loadingBubble, "Problem! Connection error.")
    } finally {
      this._setStreaming(false)
      this.inputTarget.focus()
    }
  }

  // Appends media inline inside an existing assistant bubble (tool use path)
  appendMediaToBubble(bubble, type, url) {
    const body = bubble.querySelector(".message__body") || bubble
    const el   = document.createElement("div")
    el.className = "message__media mt-2"
    el.innerHTML = this._mediaHtml(type, url)
    body.appendChild(el)
  }

  appendMedia(type, url) {
    const el = document.createElement("div")
    el.className = "message message--media"
    el.innerHTML = this._mediaHtml(type, url)
    this.messagesTarget.appendChild(el)
    this.scrollToBottom()
  }

  _mediaHtml(type, url) {
    if (type === "image") return `<img src="${url}" class="media-result--image" alt="Generated image">`
    if (type === "video") return `<video src="${url}" controls class="media-result--video"></video>`
    if (type === "music") return `<audio src="${url}" controls class="media-result--audio"></audio>`
    return ""
  }

  // ── TTS ───────────────────────────────────────────────────────────────────

  async speakText(text) {
    if (!text.trim()) return

    try {
      const response = await fetch(this.ttsUrlValue, {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token":  this.csrfToken
        },
        body: JSON.stringify({ text: text.slice(0, 2000) })
      })

      if (!response.ok) {
        this._releaseToneQueue()
        return
      }

      const arrayBuffer = await response.arrayBuffer()
      this._playTtsWithReverb(arrayBuffer)  // fire and forget — does not block

    } catch (e) {
      console.warn("Rocky TTS failed:", e)
      this._releaseToneQueue()
    }
  }

  async _playTtsWithReverb(arrayBuffer) {
    try {
      const ctx = this._getAudioCtx()
      if (ctx.state === "suspended") await ctx.resume()

      const audioBuffer = await ctx.decodeAudioData(arrayBuffer)

      // Stop any currently playing TTS
      if (this._currentTtsSrc) {
        try { this._currentTtsSrc.stop() } catch {}
        this._currentTtsSrc = null
      }

      const source  = ctx.createBufferSource()
      source.buffer = audioBuffer

      // Dry path — 82% direct
      const dryGain       = ctx.createGain()
      dryGain.gain.value  = 0.82
      source.connect(dryGain)
      dryGain.connect(ctx.destination)

      // Wet path — 18% through reverb (mechanical/transmission feel)
      const reverb        = this._getReverb()
      const wetGain       = ctx.createGain()
      wetGain.gain.value  = 0.18
      source.connect(reverb)
      reverb.connect(wetGain)
      wetGain.connect(ctx.destination)

      this._currentTtsSrc = source
      source.start()
      this._releaseToneQueue()  // TTS is playing — release tone queue

      source.addEventListener("ended", () => {
        this._currentTtsSrc = null
      })
    } catch (e) {
      console.warn("Rocky TTS reverb failed:", e)
      this._releaseToneQueue()
    }
  }

  _getAudioCtx() {
    if (!this._audioCtx) {
      this._audioCtx = new (window.AudioContext || window.webkitAudioContext)()
    }
    return this._audioCtx
  }

  _getReverb() {
    if (this._reverbNode) return this._reverbNode

    const ctx      = this._getAudioCtx()
    const reverb   = ctx.createConvolver()
    const duration = 0.25   // 250ms tail — subtle, not cavernous
    const decay    = 3.5    // fast decay = mechanical, not ambient
    const length   = Math.floor(ctx.sampleRate * duration)
    const impulse  = ctx.createBuffer(2, length, ctx.sampleRate)

    for (let c = 0; c < 2; c++) {
      const data = impulse.getChannelData(c)
      for (let i = 0; i < length; i++) {
        data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / length, decay)
      }
    }

    reverb.buffer   = impulse
    this._reverbNode = reverb
    return reverb
  }

  speakMessage(event) {
    const bubble    = event.target.closest(".message--assistant")
    const contentEl = bubble?.querySelector("[data-content]")
    if (!contentEl) return

    const text = this.stripToneMarkers(contentEl.textContent || "")
    this.speakText(text)
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  _setStreaming(val) {
    this._streaming = val
    this.sendButtonTarget.disabled = val
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.appendChild(document.createTextNode(text))
    return div.innerHTML
  }

  get csrfToken() {
    return document.querySelector('[name="csrf-token"]')?.content || ""
  }
}
