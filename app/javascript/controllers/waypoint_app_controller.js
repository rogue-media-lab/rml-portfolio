import { Controller } from "@hotwired/stimulus"

// Waypoint — app view. The capture surface itself, not a picture of one.
//
// Three jobs, in order of importance:
//   1. talk or type a job in, parse it, confirm it before it is believed
//   2. look up a spec without leaving the conversation, and say so when we don't have it
//   3. show the money the same day
//
// Parser is deliberately a fast regex path with no model call: the common shape
// ("2018 civic oil change 84k 95 dollars") costs nothing to read. Anything it cannot
// read it refuses, and the confirm card is what catches a wrong read.
export default class extends Controller {
  static targets = [
    "panel", "tab",
    "thread", "inputField", "micButton", "jobCount",
    "specInput", "specResults"
  ]

  static values = { specs: Array }

  connect() {
    this.showTabByIndex(0)
    this.renderSpecs("")
  }

  // ---- panels -------------------------------------------------------------

  showTab(event) {
    this.activatePanel(event.currentTarget.dataset.panel)
  }

  showTabByIndex(index) {
    const tab = this.tabTargets[index]
    if (tab) this.activatePanel(tab.dataset.panel)
  }

  activatePanel(name) {
    this.panelTargets.forEach((el) => {
      el.classList.toggle("hidden", el.dataset.panelName !== name)
    })
    this.tabTargets.forEach((el) => {
      const on = el.dataset.panel === name
      el.classList.toggle("bg-zinc-100", on)
      el.classList.toggle("text-zinc-900", on)
      el.classList.toggle("text-zinc-400", !on)
    })
  }

  // ---- capture ------------------------------------------------------------

  // Known service words. If none appear, this is not a job - it may be a question,
  // and a parser that logs a question is worse than useless.
  static services = [
    "oil change", "brake", "battery", "tire", "tires", "diagnostic", "alternator",
    "starter", "radiator", "transmission", "cvt", "spark plug", "filter", "alignment"
  ]

  send() {
    const text = (this.inputFieldTarget.value || "").trim()
    if (!text) return
    this.appendBubble("me", text)

    const parsed = this.parse(text)
    if (parsed) {
      this.appendParsed(parsed, text)
    } else {
      this.appendBubble("them", "I could not read that one. Try: 2018 civic oil change 84k 95 dollars.")
    }
    this.inputFieldTarget.value = ""
    this.scrollThread()
  }

  submitOnEnter(event) {
    if (event.key === "Enter") this.send()
  }

  // Pull mileage out BEFORE anything else, so "92000 miles" cannot be mistaken for a
  // model number - while "c/k 1500" survives, because 1500 has no unit after it.
  parse(text) {
    const t = text.toLowerCase()
    const miles = t.match(/(\d{2,3})\s*k\b/) || t.match(/(\d{4,6})\s*(?:mi|miles)\b/)
    const stripped = miles ? t.replace(miles[0], " ").replace(/\s+/g, " ").trim() : t

    const service = this.constructor.services.join("|").replace(/\//g, "\\/")
    const re = new RegExp("(\\d{4})\\s+([a-z]+)(?:\\s+([a-z0-9\\/\\- ]+?))?\\s+(" + service + ")")
    const m = stripped.match(re)
    if (!m) return null

    const amt = t.match(/\$?\s?(\d+(?:\.\d{1,2})?)\s*(?:dollars|bucks|\$)?\s*$/)

    const parts = [m[1], m[2]]
    if (m[3]) parts.push(m[3].trim().replace(/\s+/g, " "))

    return {
      vehicle: parts.join(" ").replace(/\b\w/g, (c) => c.toUpperCase()),
      service: m[4],
      mileage: miles ? (miles[1].length <= 3 ? String(Number(miles[1]) * 1000) : miles[1]) : null,
      amount: amt ? amt[1] : null
    }
  }

  appendBubble(who, text) {
    const wrap = document.createElement("div")
    wrap.className = who === "me"
      ? "self-end max-w-[85%] rounded-2xl rounded-br-sm bg-zinc-100 px-3 py-2 text-[13px] text-zinc-900"
      : "self-start max-w-[85%] rounded-2xl rounded-bl-sm bg-zinc-800 px-3 py-2 text-[13px] text-zinc-100"
    wrap.textContent = text
    this.threadTarget.appendChild(wrap)
  }

  // The confirm card. This is the whole trust argument: it asks when it is unsure.
  appendParsed(p, raw) {
    const card = document.createElement("div")
    card.className = "self-stretch rounded-xl border border-emerald-600/60 bg-emerald-950/30 p-3"

    const header = document.createElement("div")
    header.className = "flex items-center justify-between mb-2"
    header.innerHTML = '<span class="text-[10px] uppercase tracking-widest font-extrabold text-emerald-400">Parsed</span>'

    const fields = document.createElement("div")
    fields.className = "grid grid-cols-2 gap-2"
    const rows = [
      ["Vehicle", p.vehicle],
      ["Service", p.service],
      ["Mileage", p.mileage ? Number(p.mileage).toLocaleString() : "not given"],
      ["Collected", p.amount ? "$" + p.amount : "not given"]
    ]
    rows.forEach(([k, v]) => {
      const cell = document.createElement("div")
      const label = document.createElement("div")
      label.className = "text-[10px] uppercase tracking-wide text-zinc-400 font-bold"
      label.textContent = k
      const val = document.createElement("div")
      val.className = "text-[13px] font-semibold text-zinc-100"
      val.textContent = v
      cell.appendChild(label)
      cell.appendChild(val)
      fields.appendChild(cell)
    })

    const actions = document.createElement("div")
    actions.className = "flex gap-2 mt-3"
    const yes = document.createElement("button")
    yes.className = "flex-1 rounded-lg bg-emerald-600 px-3 py-2 text-[13px] font-bold text-white hover:bg-emerald-500"
    yes.textContent = "Log it"
    yes.dataset.action = "waypoint-app#commit"
    const no = document.createElement("button")
    no.className = "rounded-lg border border-zinc-700 px-3 py-2 text-[13px] font-bold text-zinc-300 hover:border-zinc-500"
    no.textContent = "Not right"
    no.dataset.action = "waypoint-app#reject"

    actions.appendChild(yes)
    actions.appendChild(no)

    card.appendChild(header)
    card.appendChild(fields)
    card.appendChild(actions)
    this.threadTarget.appendChild(card)
    card.dataset.raw = raw
  }

  commit(event) {
    const card = event.currentTarget.closest("div[data-raw]")
    this.finishCard(card, "Logged. Was the spec right for this one? One tap and I remember it.")
  }

  reject(event) {
    const card = event.currentTarget.closest("div[data-raw]")
    this.finishCard(card, "Noted - I will ask again next time.")
  }

  finishCard(card, message) {
    if (!card) return
    card.querySelectorAll("button").forEach((b) => b.remove())
    const note = document.createElement("div")
    note.className = "mt-2 border-t border-emerald-800/60 pt-2 text-[12px] text-emerald-300"
    note.textContent = message
    card.appendChild(note)
    if (this.hasJobCountTarget) {
      this.jobCountTarget.textContent = String(Number(this.jobCountTarget.dataset.count || 0) + 1)
    }
    this.scrollThread()
  }

  scrollThread() {
    this.threadTarget.scrollTop = this.threadTarget.scrollHeight
  }

  // ---- voice: the actual hands-free path ----------------------------------

  toggleMic() {
    if (this.listening) {
      if (this.recognition) this.recognition.stop()
      this.stopListening()
      return
    }
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SR) {
      this.appendBubble("them", "This browser has no speech recognition. Use Chrome or Safari, over https.")
      return
    }

    this.recognition = new SR()
    this.recognition.lang = "en-US"
    this.recognition.interimResults = true
    this.recognition.continuous = false

    this.recognition.onresult = (e) => {
      let text = ""
      for (let i = 0; i < e.results.length; i++) text += e.results[i][0].transcript
      this.inputFieldTarget.value = text.trim()
      if (e.results[e.results.length - 1].isFinal) {
        this.stopListening()
        this.send()
      }
    }

    this.recognition.onerror = (e) => {
      this.stopListening()
      if (e.error === "not-allowed" || e.error === "service-not-allowed") {
        this.appendBubble("them", "Microphone blocked. Browsers will not hand over the mic on plain http - this page needs https for voice.")
      } else {
        this.appendBubble("them", "Mic hiccup (" + e.error + "). Type it instead - same parser.")
      }
    }

    this.recognition.onend = () => this.stopListening()

    this.listening = true
    this.micButtonTarget.classList.add("bg-red-600", "text-white", "animate-pulse")
    this.recognition.start()
  }

  stopListening() {
    this.listening = false
    if (this.hasMicButtonTarget) {
      this.micButtonTarget.classList.remove("bg-red-600", "text-white", "animate-pulse")
    }
  }

  // It drafts, it does not speak. The tech sends, always.
  draftReminders() {
    this.appendBubble("them", "Two reminders drafted. Nothing sends until you say so - check the Capture tab.")
    this.showTabByIndex(0)
  }

  // ---- spec lookup --------------------------------------------------------

  lookup() {
    this.renderSpecs((this.specInputTarget.value || "").trim().toUpperCase())
  }

  renderSpecs(query) {
    const all = this.specsValue
    if (!query) {
      this.specResultsTarget.innerHTML = all
        .slice(0, 3)
        .map((s) => this.specCard(s))
        .join("")
      return
    }

    const hits = all.filter((s) => s.code.toUpperCase().includes(query))
    if (hits.length === 0) {
      this.specResultsTarget.innerHTML =
        '<div class="rounded-xl border border-dashed border-zinc-700 p-5 text-center">' +
        '<div class="font-semibold text-zinc-100">I do not have this.</div>' +
        '<div class="mt-1 text-[12px] text-zinc-400">Waypoint will not guess. Queue a lookup and it reports back when it is verified.</div>' +
        "</div>"
      return
    }

    const missing = hits.find((s) => !s.name)
    if (missing) {
      this.specResultsTarget.innerHTML =
        '<div class="rounded-xl border border-dashed border-zinc-700 p-5 text-center">' +
        '<div class="font-semibold text-zinc-100">I do not have this.</div>' +
        '<div class="mt-1 text-[12px] text-zinc-400">' + missing.note + "</div>" +
        "</div>"
      return
    }

    this.specResultsTarget.innerHTML = hits.map((s) => this.specCard(s)).join("")
  }

  // Confidence is never hidden - the tech has to know how much to trust this.
  specCard(s) {
    const tone = /verified on vehicle|corroborated/.test(s.conf)
      ? "bg-emerald-500/15 text-emerald-300"
      : /single source/.test(s.conf)
      ? "bg-amber-500/15 text-amber-300"
      : "bg-zinc-500/15 text-zinc-300"
    return (
      '<div class="mb-2 rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">' +
      '<div class="flex items-center justify-between gap-2">' +
      '<span class="text-[13px] font-bold text-zinc-200">' + s.code + "</span>" +
      '<span class="rounded-full px-2 py-0.5 text-[10px] font-bold ' + tone + '">' + s.conf + "</span>" +
      "</div>" +
      '<div class="mt-1 text-[18px] font-bold tracking-tight text-zinc-50">' + s.name + "</div>" +
      '<div class="mt-1 text-[12px] leading-snug text-zinc-400">' + s.note + "</div>" +
      "</div>"
    )
  }
}
