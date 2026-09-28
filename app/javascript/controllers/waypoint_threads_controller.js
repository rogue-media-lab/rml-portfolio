import { Controller } from "@hotwired/stimulus"

// Toggles active thread (brake / radiator) and active channel (welcome / waypoint / labs-lounge).
// Clicking a thread also activates the waypoint channel and deactivates the others.
export default class extends Controller {
  static targets = ["itemBrakes", "itemRadiator", "welcomeChannel", "waypointChannel", "labsLoungeChannel"]

  setActive(event) {
    const clicked = event.currentTarget
    // Toggle thread active state
    ;[this.itemBrakesTarget, this.itemRadiatorTarget].forEach((el) => {
      el.classList.remove("bg-[#404249]", "text-zinc-100")
      el.classList.add("text-zinc-300")
    })
    clicked.classList.add("bg-[#404249]", "text-zinc-100")
    clicked.classList.remove("text-zinc-300")
    // Threads live under waypoint — activate it, deactivate the others
    this.deactivateAllChannels()
    if (this.hasWaypointChannelTarget) this.activateChannel(this.waypointChannelTarget, "text")
  }

  setActiveChannel(event) {
    this.deactivateAllChannels()
    this.activateChannel(event.currentTarget, "background")
  }

  deactivateAllChannels() {
    ;[this.welcomeChannelTarget, this.waypointChannelTarget, this.labsLoungeChannelTarget].forEach((el) => {
      if (!el) return
      el.classList.remove("text-white", "font-medium", "bg-[#404249]")
      el.classList.add("text-zinc-400", "hover:bg-[#34373C]", "hover:text-zinc-100")
    })
  }

  activateChannel(el, style = "background") {
    el.classList.add("text-white", "font-medium")
    el.classList.remove("text-zinc-400", "hover:bg-[#34373C]", "hover:text-zinc-100")
    if (style === "background") el.classList.add("bg-[#404249]")
  }
}
