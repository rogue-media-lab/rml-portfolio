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
    "specInput", "specResults",
    "moneyCollected", "moneyOutstanding", "moneyCount", "todayCount"
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
      this.appendEstimate(parsed, text)
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

    // Two orders, because people say it both ways. "2021 ford escape alternator"
    // and "alternator on a 2021 ford escape" are the same job.
    let year, make, model, svc

    const yearFirst = stripped.match(
      new RegExp("(\\d{4})\\s+([a-z]+)(?:\\s+([a-z0-9\\/\\- ]+?))?\\s+(" + service + ")")
    )

    if (yearFirst) {
      year = yearFirst[1]
      make = yearFirst[2]
      model = yearFirst[3] ? yearFirst[3].trim().replace(/\s+/g, " ") : null
      svc = yearFirst[4]
    } else {
      const serviceFirst = stripped.match(
        new RegExp("(" + service + ")\\s+(?:on\\s+)?(?:a\\s+)?(\\d{4})\\s+([a-z]+)(?:\\s+([a-z0-9\\/\\- ]+))?\\s*$")
      )
      if (!serviceFirst) return null
      svc = serviceFirst[1]
      year = serviceFirst[2]
      make = serviceFirst[3]
      model = serviceFirst[4] ? serviceFirst[4].trim().replace(/\s+/g, " ") : null
    }

    const amt = t.match(/\$?\s?(\d+(?:\.\d{1,2})?)\s*(?:dollars|bucks|\$)?\s*$/)

    const parts = [year, make]
    if (model) parts.push(model)

    return {
      vehicle: parts.join(" ").replace(/\b\w/g, (c) => c.toUpperCase()),
      year: year,
      make: make,
      model: model,
      service: svc,
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

  // The estimate card. This is the whole trust argument: it quotes what it can prove
  // and names what it cannot, rather than filling a gap with a plausible number.
  async appendEstimate(p, raw) {
    const card = document.createElement("div")
    card.className = "self-stretch rounded-xl border border-emerald-600/60 bg-emerald-950/30 p-3"
    card.dataset.raw = raw
    card.innerHTML = '<div class="text-[10px] uppercase tracking-widest font-extrabold text-emerald-400">Working out the quote...</div>'
    this.threadTarget.appendChild(card)
    this.scrollThread()

    const params = new URLSearchParams({
      service: p.service,
      make: p.make || "",
      model: p.model || "",
      year: p.year || "",
      mileage: p.mileage || ""
    })

    let est = null
    try {
      const res = await fetch("/waypoint/estimate?" + params.toString(), {
        headers: { Accept: "application/json" }
      })
      if (res.ok) est = await res.json()
    } catch (e) {
      est = null
    }

    if (!est) {
      card.innerHTML = '<div class="text-[13px] text-zinc-300">Could not reach the estimator. The parse is still good - try again.</div>'
      return
    }

    const payload = { parsed: p, estimate: est }
    card.dataset.payload = JSON.stringify(payload)
    card.innerHTML = this.estimateMarkup(p, est)
    // Parts and gaps are painted from the draft rather than baked into the markup,
    // so they can be repainted in place when the tech edits.
    this.applyDraft(card, payload)
    this.scrollThread()
  }

  estimateMarkup(p, est) {
    const money = (n) => (n == null ? "-" : "$" + Number(n).toFixed(2))
    const input =
      "rounded bg-zinc-800 border border-zinc-700 px-2 py-1 text-[12px] text-zinc-100 placeholder:text-zinc-600"

    const torque = (est.torque || []).length
      ? est.torque.map((t) =>
          '<div class="flex justify-between gap-2 text-[12px] text-zinc-300"><span class="truncate">' +
          t.fastener + '</span><span class="shrink-0 font-semibold">' + t.value + " " + t.unit + "</span></div>"
        ).join("")
      : '<div class="text-[12px] text-amber-300">No torque spec on file.</div>'

    const source = est.labor_source
      ? '<span class="rounded-full bg-zinc-800 px-2 py-0.5 text-[10px] font-bold text-zinc-300">' + est.labor_source + "</span>"
      : ""

    return (
      '<div class="flex items-center justify-between mb-2">' +
        '<span class="text-[10px] uppercase tracking-widest font-extrabold text-emerald-400">Estimate</span>' +
        '<span class="text-[11px] font-semibold text-zinc-400">' + p.vehicle + "</span>" +
      "</div>" +

      '<div class="flex items-baseline justify-between border-b border-emerald-800/60 pb-2">' +
        '<span class="text-[12px] text-zinc-400">' + est.service +
          '<span data-est-mileage>' + (est.mileage ? " - " + Number(est.mileage).toLocaleString() + " mi" : "") + "</span>" +
        "</span>" +
        '<span data-est-total class="text-[22px] font-bold tracking-tight text-zinc-50">' + money(est.total) + "</span>" +
      "</div>" +

      '<div class="mt-2 flex items-center justify-between text-[12px] text-zinc-300">' +
        "<span>Labor <span data-est-hours>" + (est.labor_hours == null ? "-" : est.labor_hours + " h") + "</span> x " +
          money(est.labor_rate) + "/h</span>" +
        '<span data-est-labor class="font-semibold">' + money(est.labor_total) + "</span>" +
      "</div>" +
      '<div class="mt-0.5">' + source + "</div>" +

      '<div class="mt-2 border-t border-emerald-800/60 pt-2">' +
        '<div class="flex items-baseline justify-between mb-1">' +
          '<span class="text-[10px] uppercase tracking-wide text-zinc-500 font-bold">Parts</span>' +
          '<span data-est-parts class="text-[11px] font-semibold text-zinc-400">' + money(est.parts_total) + "</span>" +
        "</div>" +
        '<div data-est-partrows></div>' +
      "</div>" +

      '<div class="mt-2 border-t border-emerald-800/60 pt-2">' +
        '<div class="text-[10px] uppercase tracking-wide text-zinc-500 font-bold mb-1">Torque</div>' + torque +
      "</div>" +

      '<div data-est-gapbox class="mt-2 border-t border-amber-800/40 pt-2">' +
        '<div class="text-[10px] uppercase tracking-wide text-amber-400 font-bold mb-1">Not on file</div>' +
        '<div data-est-gaps></div>' +
      "</div>" +

      // A quote is rarely finished on the first pass. A tech standing at the car gives
      // what he has and fills in the rest as he works - so the card has to take it,
      // and the money has to follow as he types.
      '<div class="mt-2 border-t border-emerald-800/60 pt-2">' +
        '<div class="text-[10px] uppercase tracking-wide text-zinc-500 font-bold mb-1">Adjust</div>' +
        '<div class="flex items-center gap-2">' +
          '<label class="w-14 shrink-0 text-[11px] text-zinc-500">Mileage</label>' +
          '<input type="number" inputmode="numeric" data-edit-mileage data-action="input->waypoint-app#adjust" ' +
            'value="' + (est.mileage == null ? "" : est.mileage) + '" placeholder="not given" class="w-24 ' + input + '" />' +
        "</div>" +
        '<div class="mt-1.5 flex items-center gap-2">' +
          '<label class="w-14 shrink-0 text-[11px] text-zinc-500">Hours</label>' +
          '<input type="number" step="0.1" inputmode="decimal" data-edit-hours data-action="input->waypoint-app#adjust" ' +
            'value="' + (est.labor_hours == null ? "" : est.labor_hours) + '" placeholder="-" class="w-24 ' + input + '" />' +
          '<span class="text-[11px] text-zinc-500">x ' + money(est.labor_rate) + "/h</span>" +
        "</div>" +
        '<div class="mt-1.5 flex items-center gap-1.5">' +
          '<input type="text" data-new-part-name placeholder="part name" class="min-w-0 flex-1 ' + input + '" />' +
          '<input type="text" data-new-part-number placeholder="number" class="w-20 ' + input + '" />' +
          '<input type="number" step="0.01" data-new-part-cost placeholder="$" class="w-16 ' + input + '" />' +
          '<button type="button" data-action="waypoint-app#addPart" ' +
            'class="shrink-0 rounded bg-zinc-700 px-2.5 py-1.5 text-[12px] font-bold text-zinc-100 hover:bg-zinc-600" ' +
            'title="Add part">+</button>' +
        "</div>" +
      "</div>" +

      '<div class="mt-3 flex gap-2">' +
        '<button type="button" data-action="waypoint-app#commit" class="flex-1 rounded-lg bg-emerald-600 px-3 py-2 text-[13px] font-bold text-white hover:bg-emerald-500">Log it</button>' +
        '<button type="button" data-action="waypoint-app#reject" class="rounded-lg border border-zinc-700 px-3 py-2 text-[13px] font-bold text-zinc-300 hover:border-zinc-500">Not right</button>' +
      "</div>"
    )
  }

  // ── Adjust ─────────────────────────────────────────────────────────────────
  // Recompute the draft from the inputs, then paint. Re-rendering the whole card on
  // every keystroke would steal focus mid-type, so the editable fields stay put and
  // only the numbers and the part rows are repainted.

  recomputeGaps(parsed, est) {
    const parts = est.parts || []
    let gaps = (est.gaps || []).slice()

    // A gap the tech just closed by hand should close on the card too.
    gaps = gaps.filter((g) => !(g === "mileage not given" && parsed.mileage != null))
    gaps = gaps.filter((g) => !(g.indexOf("no parts on file") === 0 && parts.length > 0))
    gaps = gaps.filter((g) => !(g.indexOf("no torque spec") === 0 && (est.torque || []).length > 0))
    gaps = gaps.filter((g) => g.indexOf("have no cost on file") === -1)

    const uncosted = parts.filter((p) => p.unit_cost == null).length
    if (uncosted > 0) {
      gaps.push(uncosted + " of " + parts.length + " part(s) have no cost on file")
    }
    return gaps
  }

  readDraft(card, base) {
    let payload = base || null
    if (!payload) {
      try {
        payload = JSON.parse(card.dataset.payload || "null")
      } catch (e) {
        payload = null
      }
    }
    if (!payload) return null

    const parsed = payload.parsed || {}
    const est = payload.estimate || {}

    const mi = card.querySelector("[data-edit-mileage]")
    if (mi) {
      const v = mi.value.trim()
      parsed.mileage = v === "" ? null : Number(v)
    }

    const hrs = card.querySelector("[data-edit-hours]")
    if (hrs) {
      const v = hrs.value.trim()
      est.labor_hours = v === "" ? null : Number(v)
    }

    const round = (n) => Math.round(n * 100) / 100

    est.labor_total = est.labor_hours != null && est.labor_rate != null
      ? round(est.labor_hours * est.labor_rate)
      : null

    est.parts_total = round(
      (est.parts || []).reduce(
        (sum, p) => sum + (p.unit_cost == null ? 0 : Number(p.unit_cost) * Number(p.quantity || 1)),
        0
      )
    )

    est.total = round((est.labor_total || 0) + (est.parts_total || 0))
    est.mileage = parsed.mileage
    est.gaps = this.recomputeGaps(parsed, est)

    payload.parsed = parsed
    payload.estimate = est
    return payload
  }

  adjust(event) {
    const card = event.currentTarget.closest("div[data-raw]")
    if (!card) return
    const draft = this.readDraft(card)
    if (draft) this.applyDraft(card, draft)
  }

  applyDraft(card, payload) {
    card.dataset.payload = JSON.stringify(payload)
    const est = payload.estimate || {}
    const money = (n) => (n == null ? "-" : "$" + Number(n).toFixed(2))

    const set = (sel, val) => {
      const el = card.querySelector(sel)
      if (el) el.textContent = val
    }

    set("[data-est-total]", money(est.total))
    set("[data-est-labor]", money(est.labor_total))
    set("[data-est-parts]", money(est.parts_total))
    set("[data-est-hours]", est.labor_hours == null ? "-" : est.labor_hours + " h")
    set("[data-est-mileage]", est.mileage ? " - " + Number(est.mileage).toLocaleString() + " mi" : "")

    const gaps = est.gaps || []
    const gapBox = card.querySelector("[data-est-gapbox]")
    const gapHost = card.querySelector("[data-est-gaps]")
    if (gapHost) {
      gapHost.innerHTML = gaps.map((g) =>
        '<div class="text-[11px] leading-snug text-amber-300">' + g + "</div>"
      ).join("")
    }
    if (gapBox) gapBox.classList.toggle("hidden", gaps.length === 0)

    this.renderPartRows(card, payload)
  }

  renderPartRows(card, payload) {
    const host = card.querySelector("[data-est-partrows]")
    if (!host) return

    const parts = (payload.estimate || {}).parts || []
    const money = (n) => (n == null ? "no cost" : "$" + Number(n).toFixed(2))

    if (!parts.length) {
      host.innerHTML = '<div class="text-[12px] text-amber-300">No part number on file. Add one below.</div>'
      return
    }

    host.innerHTML = parts.map((pt, i) =>
      '<div class="flex items-center justify-between gap-2 text-[12px] text-zinc-300">' +
        '<span class="min-w-0 flex-1 truncate">' +
          (pt.name || "part") +
          (pt.part_number ? " - " + pt.part_number : "") +
          (Number(pt.quantity || 1) > 1 ? ' <span class="text-zinc-500">x' + pt.quantity + "</span>" : "") +
          (pt.confidence === "manual" ? ' <span class="text-[10px] text-zinc-500">added</span>' : "") +
        "</span>" +
        '<span class="shrink-0 font-semibold">' + money(pt.unit_cost) + "</span>" +
        '<button type="button" data-action="waypoint-app#removePart" data-part-index="' + i + '" ' +
          'class="shrink-0 px-1 text-[14px] leading-none text-zinc-500 hover:text-red-400" ' +
          'title="Remove this part">&times;</button>' +
      "</div>"
    ).join("")
  }

  addPart(event) {
    const card = event.currentTarget.closest("div[data-raw]")
    if (!card) return

    const nameEl = card.querySelector("[data-new-part-name]")
    const numEl = card.querySelector("[data-new-part-number]")
    const costEl = card.querySelector("[data-new-part-cost]")

    const name = nameEl && nameEl.value.trim()
    if (!name) {
      if (nameEl) nameEl.focus()
      return
    }

    const draft = this.readDraft(card)
    if (!draft) return

    draft.estimate.parts = draft.estimate.parts || []
    draft.estimate.parts.push({
      name: name,
      part_number: (numEl && numEl.value.trim()) || null,
      unit_cost: costEl && costEl.value.trim() !== "" ? Number(costEl.value) : null,
      quantity: 1,
      // A part the tech typed is not a catalog lookup. Mark it so the record is honest
      // about where the number came from.
      confidence: "manual"
    })

    if (nameEl) nameEl.value = ""
    if (numEl) numEl.value = ""
    if (costEl) costEl.value = ""

    this.applyDraft(card, this.readDraft(card, draft) || draft)
    if (nameEl) nameEl.focus()
  }

  removePart(event) {
    const card = event.currentTarget.closest("div[data-raw]")
    if (!card) return

    const index = Number(event.currentTarget.dataset.partIndex)
    const draft = this.readDraft(card)
    if (!draft || Number.isNaN(index)) return

    const parts = draft.estimate.parts || []
    parts.splice(index, 1)
    draft.estimate.parts = parts

    this.applyDraft(card, this.readDraft(card, draft) || draft)
  }

  async commit(event) {
    const card = event.currentTarget.closest("div[data-raw]")
    if (!card) return

    // Re-read the inputs first. A tech may type a mileage and tap Log it without
    // leaving the field, and an edit must not be lost on the way out the door.
    const payload = this.readDraft(card)

    if (!payload) {
      this.finishCard(card, "Nothing to log - say the job again.")
      return
    }

    const parsed = payload.parsed || {}
    const est = payload.estimate || {}

    const body = {
      job: {
        service: est.service,
        vehicle_year: parsed.year,
        vehicle_make: parsed.make,
        vehicle_model: parsed.model,
        mileage: est.mileage != null ? est.mileage : parsed.mileage,
        labor_hours: est.labor_hours,
        labor_rate: est.labor_rate,
        labor_total: est.labor_total,
        parts_total: est.parts_total,
        total: est.total,
        raw_capture: card.dataset.raw,
        parts: est.parts || [],
        torque: est.torque || [],
        gaps: est.gaps || []
      }
    }

    const meta = document.querySelector('meta[name="csrf-token"]')
    const token = meta ? meta.content : null

    let res = null
    try {
      res = await fetch("/waypoint/log", {
        method: "POST",
        headers: Object.assign(
          { "Content-Type": "application/json", Accept: "application/json" },
          token ? { "X-CSRF-Token": token } : {}
        ),
        body: JSON.stringify(body)
      })
    } catch (e) {
      this.finishCard(card, "Could not save that one - no connection. The quote is still good.")
      return
    }

    if (!res || !res.ok) {
      this.finishCard(card, "Could not save that one. It is still quoted - try again.")
      return
    }

    let data = null
    try {
      data = await res.json()
    } catch (e) {
      data = null
    }

    this.updateMoney(data)
    this.finishCard(card, "Logged. Was the spec right for this one? One tap and I remember it.")
  }

  // The money panel is computed server-side. Reflect the new totals without a reload.
  updateMoney(data) {
    if (!data) return
    const fmt = (n) => "$" + Number(n || 0).toFixed(2)
    if (this.hasMoneyCollectedTarget) this.moneyCollectedTarget.textContent = fmt(data.collected_total)
    if (this.hasMoneyOutstandingTarget) this.moneyOutstandingTarget.textContent = fmt(data.outstanding_total)
    if (this.hasMoneyCountTarget) this.moneyCountTarget.textContent = String(data.job_count || 0)
    if (this.hasTodayCountTarget) {
      this.todayCountTarget.textContent = String(Number(this.todayCountTarget.textContent || 0) + 1)
    }
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
