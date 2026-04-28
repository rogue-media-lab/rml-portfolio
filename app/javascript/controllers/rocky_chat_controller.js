import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "sendButton", "tonebars", "statusDot", "statusText", "counter"]
  static values = {
    messagesUrl: String,
    ttsUrl:      String,
    toneUrl:     String,
    promptCount: Number,
    anonLimit:   Number,
    loggedIn:    Boolean
  }

  connect() {
    this._streaming    = false
    this._toneQueue    = []
    this._tonePlaying  = false
    this._ttsReady     = false
    this._tonePending  = false
    this._audioCtx     = null
    this._analyser     = null
    this._reverbNode   = null
    this._currentTtsSrc = null
    this._playedTones  = new Set()
    this._animFrameId  = null
    this._activeSources = 0

    this.scrollToBottom()
    if (this.hasInputTarget) this.inputTarget.focus()
    this._updateCounter()
  }

  disconnect() {
    if (this._animFrameId) cancelAnimationFrame(this._animFrameId)
  }

  // ── Input handling ──────────────────────────────────────────────────────

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submit()
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────────

  async submit() {
    const content = this.inputTarget.value.trim()
    if (!content || this._streaming) return

    if (!this.loggedInValue && this.promptCountValue >= this.anonLimitValue) {
      this._showLimitMessage()
      return
    }

    this.inputTarget.value = ""
    this._setStreaming(true)
    this._setStatus("active", "PROCESSING_INPUT")

    this.appendUserMessage(content)
    const assistantBubble = this.appendAssistantBubble()

    try {
      const response = await fetch(this.messagesUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ content })
      })

      if (response.status === 403) {
        const data = await response.json()
        this._updateBubble(assistantBubble, data.message || "Limit reached.")
        this._showLimitMessage()
        return
      }

      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      this.promptCountValue++
      this._updateCounter()
      await this._consumeSSE(response, assistantBubble)

    } catch (error) {
      console.error("Rocky chat error:", error)
      this._updateBubble(assistantBubble, "Problem! Connection lost. Try again.")
    } finally {
      this._setStreaming(false)
      this._setStatus("online", "LISTENING_FOR_INPUT")
      this.inputTarget.focus()
    }
  }

  // ── SSE streaming ───────────────────────────────────────────────────────

  async _consumeSSE(response, bubble) {
    this._toneQueue   = []
    this._tonePlaying = false
    this._ttsReady    = false
    this._tonePending = false
    this._playedTones = new Set()

    const reader  = response.body.getReader()
    const decoder = new TextDecoder()
    let buffer    = ""
    let fullContent = ""

    while (true) {
      const { value, done } = await reader.read()
      if (done) break

      buffer += decoder.decode(value, { stream: true })
      const lines = buffer.split("\n")
      buffer = lines.pop()

      for (const line of lines) {
        if (!line.startsWith("data: ")) continue

        let data
        try { data = JSON.parse(line.slice(6)) } catch { continue }

        if (data.type === "content") {
          fullContent += data.delta
          this._updateBubble(bubble, fullContent)
          this.scrollToBottom()
          this._playNewTones(fullContent)

        } else if (data.type === "done") {
          const speakText = this.stripToneMarkers(fullContent)
          if (speakText.trim()) this.speakText(speakText)
          this._setStatus("online", "RESPONSE_COMPLETE")

        } else if (data.type === "error") {
          this._updateBubble(bubble, data.message || "Problem! Rocky not responding.")
        }
      }
    }
  }

  // ── Audio context & analyser ────────────────────────────────────────────

  _getAudioCtx() {
    if (!this._audioCtx) {
      this._audioCtx = new (window.AudioContext || window.webkitAudioContext)()
    }
    return this._audioCtx
  }

  _getAnalyser() {
    if (this._analyser) return this._analyser

    const ctx     = this._getAudioCtx()
    const analyser = ctx.createAnalyser()
    analyser.fftSize = 64
    analyser.smoothingTimeConstant = 0.7
    analyser.connect(ctx.destination)
    this._analyser = analyser
    return analyser
  }

  _getReverb() {
    if (this._reverbNode) return this._reverbNode

    const ctx      = this._getAudioCtx()
    const reverb   = ctx.createConvolver()
    const duration = 0.25
    const decay    = 3.5
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

  // Track active sources for waveform start/stop
  _sourceStarted() {
    this._activeSources++
    this._startWaveformLoop()
  }

  _sourceEnded() {
    this._activeSources = Math.max(0, this._activeSources - 1)
    if (this._activeSources === 0) {
      this._stopWaveformLoop()
    }
  }

  // ── Tone playback (through Web Audio analyser) ──────────────────────────

  _playNewTones(fullContent) {
    const TONE_RE = /\*(?:🎵\s*)?(.+?)(?:\s*🎵)?\*/g
    let match
    while ((match = TONE_RE.exec(fullContent)) !== null) {
      const description = match[1].trim()
      if (!this._playedTones.has(description)) {
        this._playedTones.add(description)
        this._fetchAndPlayTone(description)
      }
    }
  }

  async _fetchAndPlayTone(description) {
    try {
      const url = `${this.toneUrlValue}?description=${encodeURIComponent(description)}`
      const response = await fetch(url)
      if (!response.ok) return

      const blob = await response.blob()
      if (!blob.size) return

      const arrayBuffer = await blob.arrayBuffer()
      this._toneQueue.push(arrayBuffer)
      if (!this._tonePlaying) this._drainToneQueue()
    } catch (e) {
      // Non-critical
    }
  }

  _drainToneQueue() {
    if (this._toneQueue.length === 0) {
      this._tonePlaying = false
      return
    }

    if (!this._ttsReady) {
      this._tonePending = true
      this._tonePlaying = false
      return
    }

    this._tonePlaying = true
    const arrayBuffer = this._toneQueue.shift()

    this._playAudioThroughAnalyser(arrayBuffer, 0.3, () => {
      this._drainToneQueue()
    })
  }

  _releaseToneQueue() {
    this._ttsReady = true
    if (this._tonePending) {
      this._tonePending = false
      this._drainToneQueue()
    }
  }

  // ── Shared audio routing through analyser ───────────────────────────────

  async _playAudioThroughAnalyser(arrayBuffer, volume = 1.0, onEnded = null) {
    try {
      const ctx = this._getAudioCtx()
      if (ctx.state === "suspended") await ctx.resume()

      const analyser = this._getAnalyser()
      const audioBuffer = await ctx.decodeAudioData(arrayBuffer.slice(0))

      const source = ctx.createBufferSource()
      source.buffer = audioBuffer

      const gainNode = ctx.createGain()
      gainNode.gain.value = volume

      source.connect(gainNode)
      gainNode.connect(analyser)

      this._sourceStarted()
      source.start()

      source.addEventListener("ended", () => {
        this._sourceEnded()
        if (onEnded) onEnded()
      })

      return source
    } catch (e) {
      console.warn("Audio playback failed:", e)
      if (onEnded) onEnded()
      return null
    }
  }

  // ── TTS (through analyser + reverb) ─────────────────────────────────────

  async speakText(text) {
    if (!text.trim() || !this.hasTtsUrlValue) {
      this._releaseToneQueue()
      return
    }

    try {
      const response = await fetch(this.ttsUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ text: text.slice(0, 2000) })
      })

      if (!response.ok) {
        this._releaseToneQueue()
        return
      }

      const arrayBuffer = await response.arrayBuffer()
      this._playTtsWithReverb(arrayBuffer)
    } catch (e) {
      console.warn("Rocky TTS failed:", e)
      this._releaseToneQueue()
    }
  }

  async _playTtsWithReverb(arrayBuffer) {
    try {
      const ctx = this._getAudioCtx()
      if (ctx.state === "suspended") await ctx.resume()

      const analyser = this._getAnalyser()
      const audioBuffer = await ctx.decodeAudioData(arrayBuffer)

      if (this._currentTtsSrc) {
        try { this._currentTtsSrc.stop() } catch {}
        this._currentTtsSrc = null
      }

      const source  = ctx.createBufferSource()
      source.buffer = audioBuffer

      // Dry path → analyser (82%)
      const dryGain       = ctx.createGain()
      dryGain.gain.value  = 0.82
      source.connect(dryGain)
      dryGain.connect(analyser)

      // Wet path → reverb → analyser (18%)
      const reverb        = this._getReverb()
      const wetGain       = ctx.createGain()
      wetGain.gain.value  = 0.18
      source.connect(reverb)
      reverb.connect(wetGain)
      wetGain.connect(analyser)

      this._currentTtsSrc = source
      this._sourceStarted()
      source.start()
      this._releaseToneQueue()

      source.addEventListener("ended", () => {
        this._currentTtsSrc = null
        this._sourceEnded()
      })
    } catch (e) {
      console.warn("Rocky TTS reverb failed:", e)
      this._releaseToneQueue()
    }
  }

  // ── Real waveform visualization ─────────────────────────────────────────

  _startWaveformLoop() {
    if (this._animFrameId) return // already running
    if (!this.hasTonebarsTarget) return

    const bars = this.tonebarsTarget.querySelectorAll(".tonebar")
    if (!bars.length) return

    const analyser = this._getAnalyser()
    const dataArray = new Uint8Array(analyser.frequencyBinCount)

    const update = () => {
      analyser.getByteFrequencyData(dataArray)

      // Map frequency bins to bars (use first 9 bins for 9 bars)
      const binStep = Math.max(1, Math.floor(dataArray.length / bars.length))

      bars.forEach((bar, i) => {
        const binIndex = i * binStep
        const value = dataArray[binIndex] || 0

        // Scale: min 10% height, max 100%
        const minH = 10  // minimum percentage
        const maxH = 100
        const pct = minH + (value / 255) * (maxH - minH)

        bar.style.height = `${pct}%`
        bar.style.opacity = 0.5 + (value / 255) * 0.5
        bar.style.boxShadow = value > 30
          ? `0 0 ${8 + value / 10}px rgba(45,212,191,${0.4 + value / 500})`
          : "0 0 8px rgba(45,212,191,0.3)"
      })

      this._animFrameId = requestAnimationFrame(update)
    }

    this._animFrameId = requestAnimationFrame(update)
  }

  _stopWaveformLoop() {
    if (this._animFrameId) {
      cancelAnimationFrame(this._animFrameId)
      this._animFrameId = null
    }

    // Reset bars to idle state
    if (this.hasTonebarsTarget) {
      const bars = this.tonebarsTarget.querySelectorAll(".tonebar")
      bars.forEach((bar, i) => {
        bar.style.height = bar.dataset.idleHeight || `${30 + (i % 3) * 20}%`
        bar.style.opacity = "0.4"
        bar.style.boxShadow = "0 0 8px rgba(45,212,191,0.3)"
      })
    }
  }

  // ── Content formatting ──────────────────────────────────────────────────

  formatContent(text) {
    return text
      .replace(/\*(?:🎵\s*)?(.+?)(?:\s*🎵)?\*/g, '<span class="text-yellow-400 font-mono text-[13px] opacity-80 tracking-[0.05em]">*$1*</span>')
      .replace(/\n/g, "<br>")
  }

  stripToneMarkers(text) {
    return text
      .replace(/\*(?:🎵\s*)?.+?(?:\s*🎵)?\*/g, "")
      .replace(/\s+/g, " ")
      .trim()
  }

  // ── Bubble helpers ──────────────────────────────────────────────────────

  _updateBubble(bubble, fullText) {
    const contentEl = bubble.querySelector("[data-content]")
    if (contentEl) contentEl.innerHTML = this.formatContent(fullText)
  }

  appendUserMessage(content) {
    const el = document.createElement("div")
    el.className = "flex justify-end"
    el.innerHTML = `
      <div class="max-w-[440px] rounded-t-2xl rounded-br-sm rounded-bl-2xl py-5 px-6 bg-zinc-900 border border-zinc-800 shadow-[0_4px_20px_rgba(0,0,0,0.5)]">
        <p class="text-[16px] leading-[1.5] text-zinc-50 font-['Inter',system-ui,sans-serif]" data-content>${this.escapeHtml(content)}</p>
      </div>
    `
    this.messagesTarget.appendChild(el)
    this.scrollToBottom()
    return el
  }

  appendAssistantBubble() {
    const el = document.createElement("div")
    el.className = "flex flex-col gap-3"
    el.innerHTML = `
      <span class="opacity-80 tracking-[0.05em] text-yellow-400 font-mono text-[13px]" data-tone>*processing input…*</span>
      <div class="max-w-[580px] rounded-tl-sm rounded-bl-2xl rounded-r-2xl bg-teal-400/5 border-l-4 border-teal-400 shadow-[0_10px_30px_rgba(45,212,191,0.05)] p-7">
        <p class="text-[22px] leading-[1.5] tracking-[0.02em] text-zinc-50 font-['Barlow_Condensed',system-ui,sans-serif] font-medium m-0" data-content>
          <span class="opacity-50">♪ thinking…</span>
        </p>
      </div>
    `
    this.messagesTarget.appendChild(el)
    this.scrollToBottom()
    return el
  }

  _showLimitMessage() {
    const el = document.createElement("div")
    el.className = "flex flex-col gap-3"
    el.innerHTML = `
      <div class="max-w-[580px] rounded-2xl bg-zinc-900/50 border border-zinc-800 p-7 text-center">
        <p class="text-[16px] leading-[1.5] text-zinc-400 font-['Inter',system-ui,sans-serif]">
          You've used all ${this.anonLimitValue} free prompts.
        </p>
        <p class="text-[14px] text-zinc-500 font-['Inter',system-ui,sans-serif] mt-2">
          Sign in to keep chatting with Rocky.
        </p>
      </div>
    `
    this.messagesTarget.appendChild(el)
    this.scrollToBottom()
  }

  // ── UI state ────────────────────────────────────────────────────────────

  _setStreaming(val) {
    this._streaming = val
    if (this.hasSendButtonTarget) this.sendButtonTarget.disabled = val
  }

  _setStatus(state, text) {
    if (this.hasStatusDotTarget) {
      this.statusDotTarget.className = this.statusDotTarget.className.replace(
        /bg-(green|yellow|red)-\d+/,
        state === "active" ? "bg-yellow-400" : state === "error" ? "bg-red-400" : "bg-green-400"
      )
    }
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = `STATUS: ${state.toUpperCase()} // ${text}`
    }
  }

  _updateCounter() {
    if (this.hasCounterTarget && !this.loggedInValue) {
      const remaining = Math.max(0, this.anonLimitValue - this.promptCountValue)
      this.counterTarget.textContent = `${remaining} prompts remaining`
    }
  }

  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
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
