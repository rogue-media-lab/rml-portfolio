import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list"]

  add() {
    const idx = this.listTarget.querySelectorAll("[data-job-parts-target='row']").length
    const html = this.#rowTemplate(idx)
    this.listTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(event) {
    event.currentTarget.closest("[data-job-parts-target='row']").remove()
  }

  // Shared row template — styling consistent with both create and edit forms
  #rowTemplate(idx) {
    return `
      <div class="flex gap-2 items-end mb-2" data-job-parts-target="row">
        <div class="flex-1">
          <input type="text" name="parts[${idx}][name]" placeholder="Part name"
            class="w-full rounded-lg bg-carus-black border border-[#2A2A2A] text-white text-sm px-3 py-2 focus:outline-none focus:border-carus-green/50 placeholder:text-[#FFFFFF33]">
        </div>
        <div class="w-14 shrink-0">
          <input type="number" name="parts[${idx}][quantity]" value="1" min="1" placeholder="Qty"
            class="w-full rounded-lg bg-carus-black border border-[#2A2A2A] text-white text-sm px-3 py-2 focus:outline-none focus:border-carus-green/50 placeholder:text-[#FFFFFF33] text-center">
        </div>
        <div class="w-20 shrink-0">
          <input type="text" name="parts[${idx}][cost]" placeholder="Cost"
            class="w-full rounded-lg bg-carus-black border border-[#2A2A2A] text-white text-sm px-3 py-2 focus:outline-none focus:border-carus-green/50 placeholder:text-[#FFFFFF33]">
        </div>
        <button type="button" data-action="click->job-parts#remove"
          class="shrink-0 text-[#FFFFFF33] hover:text-red-400 p-1">
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M4 4l6 6M10 4l-6 6" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>
        </button>
      </div>`
  }
}
