import { Controller } from "@hotwired/stimulus"

// Waypoint — app view. The capture surface itself, not a picture of one.
//
// Three jobs, in order of importance:
//   1. talk or type a job in, parse it, confirm it before it is believed
//   2. look up a spec without leaving the conversation, and say so when we don't have it
//   3. show the money the same day
//
// Parsing lives on the server (Waypoint::CaptureParser) so it can be tested and so SMS
// can use the same one. It is a fast regex path with no model call: the common shape
// costs nothing to read. Anything it cannot read it refuses, and the confirm card is
// what catches a wrong read.
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

  async send() {
    const text = (this.inputFieldTarget.value || "").trim()
    if (!text) return

    this.appendBubble("me", text)
    this.inputFieldTarget.value = ""
    this.scrollThread()

    const card = document.createElement("div")
    card.className = "self-stretch rounded-xl border border-emerald-600/60 bg-emerald-950/30 p-3"
    card.dataset.raw = text
    card.innerHTML =
      '<div class="text-[10px] uppercase tracking-widest font-extrabold text-emerald-400">Working out the quote...</div>'
    this.threadTarget.appendChild(card)
    this.scrollThread()

    // Parsing happens on the server now, in the same parser SMS will use. The browser
    // no longer keeps a second copy of the rules - two parsers is two things to drift.
    const meta = document.querySelector('meta[name="csrf-token"]')
    const token = meta ? meta.content : null

    let res = null
    try {
      res = await fetch("/waypoint/capture", {
        method: "POST",
        headers: Object.assign(
          { "Content-Type": "application/json", Accept: "application/json" },
          token ? { "X-CSRF-Token": token } : {}
        ),
        body: JSON.stringify({ text: text })
      })
    } catch (e) {
      card.innerHTML =
        '<div class="text-[13px] text-zinc-300">Could not reach the parser - no connection. Your words are above.</div>'
      return
    }

    if (res.status === 422) {
      card.remove()
      this.appendBubble(
        "them",
        "I could not find a job in that one. Try: alternator on a 2021 ford escape 84k."
      )
      return
    }

    if (!res.ok) {
      card.innerHTML =
        '<div class="text-[13px] text-zinc-300">Could not work out that quote. Your words are above - try again.</div>'
      return
    }

    let data = null
    try {
      data = await res.json()
    } catch (e) {
      data = null
    }

    if (!data) {
      card.innerHTML = '<div class="text-[13px] text-zinc-300">Could not read the answer. Try again.</div>'
      return
    }

    const payload = { parsed: data.parsed, estimate: data.estimate }
    card.dataset.payload = JSON.stringify(payload)
    card.innerHTML = this.estimateMarkup(data.parsed, data.estimate)
    this.applyDraft(card, payload)
    this.scrollThread()
  }

  submitOnEnter(event) {
    if (event.key === "Enter") this.send()
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
  // One card, built the same way for a fresh quote and for a job being reopened.
  buildCard(payload, raw) {
    const card = document.createElement("div")
    card.className = "self-stretch rounded-xl border border-emerald-600/60 bg-emerald-950/30 p-3"
    card.dataset.raw = raw || ""
    card.dataset.payload = JSON.stringify(payload)
    card.innerHTML = this.estimateMarkup(payload.parsed || {}, payload.estimate || {})
    this.applyDraft(card, payload)
    return card
  }

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
    const cust = p.customer || {}
    // Field values go into attributes, so a stray quote in a name must not break out.
    const attr = (v) =>
      String(v == null ? "" : v)
        .replace(/&/g, "&amp;")
        .replace(/"/g, "&quot;")
        .replace(/</g, "&lt;")

    // A label/input pair, because there are a lot of these now and they must scan fast
    // on a phone in a driveway.
    const row = (label, inner) =>
      '<div class="mt-1.5 flex items-center gap-1.5">' +
        '<label class="w-14 shrink-0 text-[11px] text-zinc-500">' + label + "</label>" +
        inner +
      "</div>"

    const field = (dataAttr, value, placeholder, extra) =>
      "<input type=\"text\" data-" + dataAttr +
      ' data-action="input->waypoint-app#adjust" value="' + attr(value) +
      '" placeholder="' + placeholder + '" class="' + (extra || "") + input + '" />'

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

        // You will not have all of this at the roadside. It is here so it can be filled in
        // when you do - the VIN especially, because it is what makes the car findable
        // again next time whatever anyone calls it.
        '<div class="mt-2.5 border-t border-zinc-800 pt-2">' +
          '<div class="text-[10px] uppercase tracking-wide text-zinc-500 font-bold mb-1">Vehicle &amp; customer</div>' +
          row("VIN", field("edit-vin", p.vin, "17 characters", "min-w-0 flex-1 font-mono ")) +
          row("Plate", field("edit-plate", p.plate, "ABC1234", "min-w-0 flex-1 ") +
            field("edit-plate-state", p.plate_state, "SC", "w-12 uppercase ")) +
          row("Engine", field("edit-engine", p.engine, "5.3L", "w-20 ")) +
          row("Color", field("edit-color", p.color, "white", "min-w-0 flex-1 ")) +
          row("Customer", field("edit-customer-name", cust.name, "name", "min-w-0 flex-1 ") +
            field("edit-customer-phone", cust.phone, "phone", "w-24 ")) +
          row("Address", field("edit-customer-address", cust.address, "street, city", "min-w-0 flex-1 ")) +
        "</div>" +
      "</div>" +

      // A replaceable slot. An unsaved quote shows Log it / Not right; a saved job
      // shows Save changes and a status, without rebuilding the card around it.
      '<div data-card-footer class="mt-3 flex gap-2">' +
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

    // Identity and customer. These are read straight off the card so they can be filled
    // in after the fact - a tech rarely has the VIN when he first says the job.
    const fields = {
      "[data-edit-vin]": "vin",
      "[data-edit-plate]": "plate",
      "[data-edit-plate-state]": "plate_state",
      "[data-edit-engine]": "engine",
      "[data-edit-color]": "color"
    }
    Object.keys(fields).forEach((selector) => {
      const el = card.querySelector(selector)
      if (el) parsed[fields[selector]] = el.value.trim() || null
    })

    parsed.customer = Object.assign({}, parsed.customer || {})
    const customerFields = {
      "[data-edit-customer-name]": "name",
      "[data-edit-customer-phone]": "phone",
      "[data-edit-customer-address]": "address"
    }
    Object.keys(customerFields).forEach((selector) => {
      const el = card.querySelector(selector)
      if (el) parsed.customer[customerFields[selector]] = el.value.trim() || null
    })

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
    if (card.dataset.jobId) this.markDirty(card)
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
    if (card.dataset.jobId) this.markDirty(card)
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
    if (card.dataset.jobId) this.markDirty(card)
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

    const body = this.jobBody(card, payload)

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

    if (data && data.id) card.dataset.jobId = data.id
    this.updateMoney(data)

    // The card stays live afterwards. A job that can be logged but never corrected is
    // a form, not a tool - and the mileage usually turns up after the quote does.
    this.showSavedFooter(card, "Logged")
  }

  // Shared by Log it and Save changes, so both send exactly the same shape.
  jobBody(card, payload) {
    const parsed = payload.parsed || {}
    const est = payload.estimate || {}
    return {
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

        // Findability. Without these a job is a receipt you cannot search.
        vin: parsed.vin,
        plate: parsed.plate,
        plate_state: parsed.plate_state,
        vehicle_color: parsed.color,
        vehicle_engine: parsed.engine,
        customer_name: (parsed.customer || {}).name,
        customer_phone: (parsed.customer || {}).phone,
        customer_address: (parsed.customer || {}).address,

        parts: est.parts || [],
        torque: est.torque || [],
        gaps: est.gaps || []
      }
    }
  }

  // ── Editing a job that is already saved ────────────────────────────────────
  // The Recent list reopens a logged job in this same card. Nothing here is a
  // second editor: it reads and writes the identical draft shape.

  showSavedFooter(card, message) {
    const footer = card.querySelector("[data-card-footer]")
    if (!footer) return

    const current = card.dataset.status || "quoted"
    const statuses = ["quoted", "done", "paid"]

    footer.className = "mt-3 border-t border-emerald-800/60 pt-2"
    footer.innerHTML =
      '<div class="flex items-center justify-between gap-2">' +
        '<span data-save-note class="text-[11px] font-semibold text-emerald-300">' +
          (message || "Saved") +
        "</span>" +
        '<button type="button" data-action="waypoint-app#saveJob" ' +
          'class="rounded-lg bg-emerald-600 px-3 py-1.5 text-[12px] font-bold text-white hover:bg-emerald-500">' +
          "Save changes</button>" +
      "</div>" +
      '<div class="mt-2 flex items-center gap-1.5">' +
        '<span class="text-[10px] font-bold uppercase tracking-wide text-zinc-500">Status</span>' +
        statuses.map((s) => this.statusButton(s, s === current)).join("") +
      "</div>"
    this.scrollThread()
  }

  statusButton(status, on) {
    return (
      '<button type="button" data-action="waypoint-app#setStatus" data-status="' + status + '" ' +
      'class="rounded-full px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wide ' +
      (on ? "bg-emerald-600 text-white" : "bg-zinc-800 text-zinc-400 hover:text-zinc-200") + '">' +
      status + "</button>"
    )
  }

  setStatus(event) {
    const card = event.currentTarget.closest("div[data-raw]")
    if (!card) return
    card.dataset.status = event.currentTarget.dataset.status
    card.querySelectorAll("[data-status]").forEach((b) => {
      const on = b.dataset.status === card.dataset.status
      b.className = "rounded-full px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wide " +
        (on ? "bg-emerald-600 text-white" : "bg-zinc-800 text-zinc-400 hover:text-zinc-200")
    })
    this.markDirty(card)
  }

  // Say out loud that there is something to save. A silent edit that only lands if
  // you remember to tap Save is how a wrong number stays in the record.
  markDirty(card) {
    const note = card.querySelector("[data-save-note]")
    if (note) note.textContent = "Unsaved changes"
  }

  editJob(event) {
    const row = event.currentTarget

    let draft = null
    try {
      draft = JSON.parse(row.dataset.job || "null")
    } catch (e) {
      draft = null
    }
    if (!draft) return

    this.activatePanel("capture")

    const card = this.buildCard(draft, (draft.parsed && draft.parsed.raw) || "")
    card.dataset.jobId = row.dataset.jobId
    card.dataset.status = row.dataset.jobStatus || "quoted"
    this.threadTarget.appendChild(card)

    this.showSavedFooter(card, "Editing job #" + row.dataset.jobId + " - change what you need, then save.")
  }

  async saveJob(event) {
    const card = event.currentTarget.closest("div[data-raw]")
    if (!card) return

    const jobId = card.dataset.jobId
    if (!jobId) {
      this.saveNote(card, "Not saved yet - tap Log it first.", true)
      return
    }

    const payload = this.readDraft(card)
    if (!payload) return

    const body = this.jobBody(card, payload)
    if (card.dataset.status) body.job.status = card.dataset.status

    const meta = document.querySelector('meta[name="csrf-token"]')
    const token = meta ? meta.content : null

    let res = null
    try {
      res = await fetch("/waypoint/jobs/" + jobId, {
        method: "PATCH",
        headers: Object.assign(
          { "Content-Type": "application/json", Accept: "application/json" },
          token ? { "X-CSRF-Token": token } : {}
        ),
        body: JSON.stringify(body)
      })
    } catch (e) {
      this.saveNote(card, "Could not save - no connection. Your change is still on screen.", true)
      return
    }

    if (!res || !res.ok) {
      this.saveNote(card, "Could not save that change. Try again.", true)
      return
    }

    let data = null
    try {
      data = await res.json()
    } catch (e) {
      data = null
    }

    this.updateMoney(data)
    this.saveNote(card, "Saved")
    if (data && data.draft) this.refreshRow(jobId, data)
  }

  saveNote(card, text, bad) {
    const note = card.querySelector("[data-save-note]")
    if (!note) return
    note.textContent = text
    note.className = "text-[11px] font-semibold " + (bad ? "text-red-400" : "text-emerald-300")
  }

  // Keep the Recent list honest without a full reload.
  refreshRow(jobId, data) {
    const row = document.querySelector(
      '[data-action="waypoint-app#editJob"][data-job-id="' + jobId + '"]'
    )
    if (!row) return

    row.dataset.job = JSON.stringify(data.draft)
    row.dataset.jobStatus = data.status

    const total = row.querySelector("[data-row-total]")
    if (total) total.textContent = "$" + Number(data.total || 0).toFixed(2)

    const status = row.querySelector("[data-row-status]")
    if (status) status.textContent = data.status
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
