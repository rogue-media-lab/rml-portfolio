import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "messages", "input", "sendButton", "counter",
    "toneGlow", "toneCircleOuter", "toneCircleInner", "toneDiamond",
    "speechbars"
  ]
  static values = {
    messagesUrl: String,
    ttsUrl:      String,
    toneUrl:     String,
    promptCount: Number,
    anonLimit:   Number,
    loggedIn:    Boolean
  }

  connect() {
    this._streaming     = false
    this._toneQueue     = []
    this._tonePlaying   = false
    this._ttsReady      = false
    this._tonePending   = false
    this._audioCtx      = null
    this._toneAnalyser  = null   // drives circles (tones)
    this._speechAnalyser = null  // drives bars (TTS)
    this._reverbNode    = null
    this._currentTtsSrc = null
    this._playedTones   = new Set()
    this._toneAnimId    = null
    this._speechAnimId  = null
    this._activeTones   = 0
    this._activeSpeech  = 0

    this.scrollToBottom()
    if (this.hasInputTarget) this.inputTarget.focus()
    this._updateCounter()
  }

  disconnect() {
    if (this._toneAnimId) cancelAnimationFrame(this._toneAnimId)
    if (this._speechAnimId) cancelAnimationFrame(this._speechAnimId)
  }

  // ── Input ───────────────────────────────────────────────────────────────

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

    // Warm up AudioContext inside the user gesture (Enter keypress).
    // Mobile browsers require ctx creation + resume within a direct gesture;
    // by the time TTS audio arrives async, the gesture window has expired.
    this._warmUpAudio()

    this.inputTarget.value = ""
    this._setStreaming(true)

    this.appendUserMessage(content)
    const assistantBubble = this.appendAssistantBubble()

    try {
      const response = await fetch(this.messagesUrlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken },
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
        } else if (data.type === "error") {
          this._updateBubble(bubble, data.message || "Problem! Rocky not responding.")
        }
      }
    }
  }

  // ── Audio context ───────────────────────────────────────────────────────

  _getAudioCtx() {
    if (!this._audioCtx) {
      this._audioCtx = new (window.AudioContext || window.webkitAudioContext)()
    }
    return this._audioCtx
  }

  // Mobile browsers suspend AudioContext until a user gesture resumes it.
  // Call this inside a gesture handler (e.g. submit/keydown) so the context
  // is ready by the time async audio data arrives.
  async _warmUpAudio() {
    try {
      const ctx = this._getAudioCtx()
      if (ctx.state === "suspended") await ctx.resume()
      console.log("[Rocky] AudioContext warmed up, state:", ctx.state)
    } catch (e) {
      console.warn("[Rocky] AudioContext warmup failed:", e)
    }
  }

  // Tone analyser → drives circles
  _getToneAnalyser() {
    if (this._toneAnalyser) return this._toneAnalyser
    const ctx = this._getAudioCtx()
    const analyser = ctx.createAnalyser()
    analyser.fftSize = 64
    analyser.smoothingTimeConstant = 0.4
    analyser.connect(ctx.destination)
    this._toneAnalyser = analyser
    return analyser
  }

  // Speech analyser → drives bars
  _getSpeechAnalyser() {
    if (this._speechAnalyser) return this._speechAnalyser
    const ctx = this._getAudioCtx()
    const analyser = ctx.createAnalyser()
    analyser.fftSize = 64
    analyser.smoothingTimeConstant = 0.7
    analyser.connect(ctx.destination)
    this._speechAnalyser = analyser
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
    reverb.buffer = impulse
    this._reverbNode = reverb
    return reverb
  }

  // ── Tone playback (→ tone analyser → circles) ───────────────────────────

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
    } catch (e) { /* non-critical */ }
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

    // Play through tone analyser (circles layer)
    this._playThroughAnalyser(arrayBuffer, this._getToneAnalyser(), 0.15, () => {
      this._activeTones--
      if (this._activeTones <= 0) {
        this._activeTones = 0
        this._stopToneLoop()
      }
      this._drainToneQueue()
    })
    this._activeTones++
    this._startToneLoop()
  }

  _releaseToneQueue() {
    this._ttsReady = true
    if (this._tonePending) {
      this._tonePending = false
      this._drainToneQueue()
    }
  }

  // ── TTS playback (→ speech analyser → bars) ─────────────────────────────

  async speakText(text) {
    if (!text.trim() || !this.hasTtsUrlValue) {
      this._releaseToneQueue()
      return
    }
    try {
      const response = await fetch(this.ttsUrlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken },
        body: JSON.stringify({ text: text.slice(0, 2000) })
      })
      if (!response.ok) { this._releaseToneQueue(); return }
      const arrayBuffer = await response.arrayBuffer()
      this._playTtsWithReverb(arrayBuffer)
    } catch (e) {
      console.warn("[Rocky] TTS fetch failed:", e)
      this._releaseToneQueue()
    }
  }

  async _playTtsWithReverb(arrayBuffer) {
    try {
      const ctx = this._getAudioCtx()
      if (ctx.state === "suspended") {
        console.warn("[Rocky] AudioContext still suspended at TTS play time, attempting resume")
        await ctx.resume()
      }
      console.log("[Rocky] TTS decoding", arrayBuffer.byteLength, "bytes, ctx state:", ctx.state)

      const speechAnalyser = this._getSpeechAnalyser()
      const audioBuffer = await ctx.decodeAudioData(arrayBuffer)
      console.log("[Rocky] TTS decoded OK, duration:", audioBuffer.duration, "s")

      if (this._currentTtsSrc) {
        try { this._currentTtsSrc.stop() } catch {}
        this._currentTtsSrc = null
      }

      const source = ctx.createBufferSource()
      source.buffer = audioBuffer

      // Dry path → speech analyser (82%)
      const dryGain = ctx.createGain()
      dryGain.gain.value = 0.82
      source.connect(dryGain)
      dryGain.connect(speechAnalyser)

      // Wet path → reverb → speech analyser (18%)
      const reverb = this._getReverb()
      const wetGain = ctx.createGain()
      wetGain.gain.value = 0.18
      source.connect(reverb)
      reverb.connect(wetGain)
      wetGain.connect(speechAnalyser)

      this._currentTtsSrc = source
      this._activeSpeech++
      this._startSpeechLoop()
      source.start()
      this._releaseToneQueue()

      source.addEventListener("ended", () => {
        this._currentTtsSrc = null
        this._activeSpeech--
        if (this._activeSpeech <= 0) {
          this._activeSpeech = 0
          this._stopSpeechLoop()
        }
      })
    } catch (e) {
      console.warn("[Rocky] TTS playback failed:", e)
      this._releaseToneQueue()
    }
  }

  // ── Shared audio player ─────────────────────────────────────────────────

  async _playThroughAnalyser(arrayBuffer, analyser, volume, onEnded) {
    try {
      const ctx = this._getAudioCtx()
      if (ctx.state === "suspended") {
        console.warn("[Rocky] AudioContext still suspended at tone play time, attempting resume")
        await ctx.resume()
      }
      const audioBuffer = await ctx.decodeAudioData(arrayBuffer.slice(0))
      const source = ctx.createBufferSource()
      source.buffer = audioBuffer
      const gain = ctx.createGain()
      gain.gain.value = volume
      source.connect(gain)
      gain.connect(analyser)
      source.start()
      source.addEventListener("ended", () => { if (onEnded) onEnded() })
    } catch (e) {
      console.warn("[Rocky] Tone playback failed:", e)
      if (onEnded) onEnded()
    }
  }

  // ── LAYER 1: Tone visualization (circles + diamond) ─────────────────────

  _startToneLoop() {
    if (this._toneAnimId) return
    const analyser = this._getToneAnalyser()
    const dataArray = new Uint8Array(analyser.frequencyBinCount)

    const update = () => {
      analyser.getByteFrequencyData(dataArray)

      // Average energy across all bins
      let sum = 0
      for (let i = 0; i < dataArray.length; i++) sum += dataArray[i]
      const avg = sum / dataArray.length
      const norm = avg / 255  // 0..1
      // Boost the curve — make it more reactive
      const boosted = Math.pow(norm, 0.6)

      // Outer circle: border opacity pulses 0.08 → 1.0, scale pulses
      if (this.hasToneCircleOuterTarget) {
        const outerAlpha = 0.08 + boosted * 0.92
        this.toneCircleOuterTarget.style.borderColor = `rgba(251,191,36,${outerAlpha})`
        const scale = 1 + boosted * 0.08
        this.toneCircleOuterTarget.style.transform = `scale(${scale})`
        // Add glow shadow when active
        const shadowBlur = boosted * 40
        this.toneCircleOuterTarget.style.boxShadow = boosted > 0.1
          ? `0 0 ${shadowBlur}px rgba(251,191,36,${boosted * 0.5})`
          : "none"
      }

      // Inner circle: border opacity pulses 0.15 → 1.0, bigger scale
      if (this.hasToneCircleInnerTarget) {
        const innerAlpha = 0.15 + boosted * 0.85
        this.toneCircleInnerTarget.style.borderColor = `rgba(251,191,36,${innerAlpha})`
        const scale = 1 + boosted * 0.12
        this.toneCircleInnerTarget.style.transform = `scale(${scale})`
        const shadowBlur = boosted * 30
        this.toneCircleInnerTarget.style.boxShadow = boosted > 0.1
          ? `0 0 ${shadowBlur}px rgba(251,191,36,${boosted * 0.4})`
          : "none"
      }

      // Diamond glow intensifies significantly
      if (this.hasToneDiamondTarget) {
        const glowInner = 30 + boosted * 60
        const glowOuter = 50 + boosted * 100
        const alpha = 0.3 + boosted * 0.7
        this.toneDiamondTarget.style.boxShadow =
          `inset 0 0 ${glowInner}px rgba(251,191,36,${alpha}), 0 0 ${glowOuter}px rgba(251,191,36,${alpha})`
        this.toneDiamondTarget.style.borderColor = `rgba(251,191,36,${0.7 + boosted * 0.3})`
        // Scale the diamond slightly
        const dScale = 1 + boosted * 0.06
        this.toneDiamondTarget.style.transform = `rotate(45deg) scale(${dScale})`
      }

      // Radial glow expands and brightens significantly
      if (this.hasToneGlowTarget) {
        const glowAlpha = 0.10 + boosted * 0.45
        this.toneGlowTarget.style.backgroundImage =
          `radial-gradient(circle farthest-corner at 50% 50% in oklab, oklab(83.7% 0.016 0.164 / ${glowAlpha}) 0%, oklab(0% 0 .0001 / 0%) 70%)`
        // Scale the glow
        const gScale = 1 + boosted * 0.15
        this.toneGlowTarget.style.transform = `scale(${gScale})`
      }

      this._toneAnimId = requestAnimationFrame(update)
    }

    this._toneAnimId = requestAnimationFrame(update)
  }

  _stopToneLoop() {
    if (this._toneAnimId) {
      cancelAnimationFrame(this._toneAnimId)
      this._toneAnimId = null
    }

    // Reset to idle
    if (this.hasToneCircleOuterTarget) {
      this.toneCircleOuterTarget.style.borderColor = "rgba(251,191,36,0.08)"
      this.toneCircleOuterTarget.style.transform = "scale(1)"
    }
    if (this.hasToneCircleInnerTarget) {
      this.toneCircleInnerTarget.style.borderColor = "rgba(251,191,36,0.15)"
      this.toneCircleInnerTarget.style.transform = "scale(1)"
    }
    if (this.hasToneDiamondTarget) {
      this.toneDiamondTarget.style.boxShadow = "inset 0 0 30px rgba(251,191,36,0.3), 0 0 50px rgba(251,191,36,0.5)"
      this.toneDiamondTarget.style.borderColor = "rgba(251,191,36,1)"
    }
    if (this.hasToneGlowTarget) {
      this.toneGlowTarget.style.backgroundImage =
        "radial-gradient(circle farthest-corner at 50% 50% in oklab, oklab(83.7% 0.016 0.164 / 0.10) 0%, oklab(0% 0 .0001 / 0%) 70%)"
    }
  }

  // ── LAYER 2: Speech visualization (bars) ────────────────────────────────

  _startSpeechLoop() {
    if (this._speechAnimId) return
    if (!this.hasSpeechbarsTarget) return

    const bars = this.speechbarsTarget.querySelectorAll(".speechbar")
    if (!bars.length) return

    const analyser = this._getSpeechAnalyser()
    const dataArray = new Uint8Array(analyser.frequencyBinCount)
    const binStep = Math.max(1, Math.floor(dataArray.length / bars.length))

    const update = () => {
      analyser.getByteFrequencyData(dataArray)

      bars.forEach((bar, i) => {
        const value = dataArray[i * binStep] || 0
        const pct = 10 + (value / 255) * 90
        bar.style.height = `${pct}%`
        bar.style.opacity = 0.3 + (value / 255) * 0.7
        bar.style.boxShadow = value > 30
          ? `0 0 ${8 + value / 8}px rgba(45,212,191,${0.4 + value / 400})`
          : "0 0 8px rgba(45,212,191,0.3)"
      })

      this._speechAnimId = requestAnimationFrame(update)
    }

    this._speechAnimId = requestAnimationFrame(update)
  }

  _stopSpeechLoop() {
    if (this._speechAnimId) {
      cancelAnimationFrame(this._speechAnimId)
      this._speechAnimId = null
    }

    // Reset bars to idle
    if (this.hasSpeechbarsTarget) {
      const bars = this.speechbarsTarget.querySelectorAll(".speechbar")
      bars.forEach(bar => {
        const idle = bar.dataset.idleHeight || "30%"
        bar.style.height = idle
        bar.style.opacity = "0.3"
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
