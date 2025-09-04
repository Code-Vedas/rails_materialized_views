/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
import { Controller } from "@hotwired/stimulus";
export default class extends Controller {
  static values = {
    enabled: { type: Boolean, default: true },
    gap: { type: Number, default: 8 },
    margin: { type: Number, default: 8 },
  };

  connect() {
    if (!this.enabledValue) return;
    this.installConfirmHooks();
  }

  disconnect() {
    this.uninstallConfirmHooks();
    this.cleanup(false);
  }

  // ──────────────────────────────────────────────
  // Turbo hook wiring
  // ──────────────────────────────────────────────
  installConfirmHooks() {
    if (!this.hasTurbo()) return;
    this.prevFormsConfirm = window.Turbo.config.forms?.confirm;
    this.prevLinksConfirm = window.Turbo.config.links?.confirm;

    const handler = this.confirm.bind(this);
    if (window.Turbo.config.forms) window.Turbo.config.forms.confirm = handler;
    if (window.Turbo.config.links) window.Turbo.config.links.confirm = handler;
  }

  uninstallConfirmHooks() {
    if (!this.hasTurbo()) return;
    if (window.Turbo.config.forms)
      window.Turbo.config.forms.confirm = this.prevFormsConfirm;
    if (window.Turbo.config.links)
      window.Turbo.config.links.confirm = this.prevLinksConfirm;
  }

  hasTurbo() {
    return !!window.Turbo?.config;
  }

  // ──────────────────────────────────────────────
  // Confirm entry point
  // ──────────────────────────────────────────────
  confirm(message, element) {
    // Fallback for Turbo < 8 or if anything is missing
    if (!this.hasTurbo()) return Promise.resolve(window.confirm(message));

    return new Promise((resolve) => {
      this._resolver = resolve;
      this.open(message, element);
    });
  }

  // ──────────────────────────────────────────────
  // Open/close lifecycle
  // ──────────────────────────────────────────────
  open(message, element) {
    this.pop = this.ensurePopover();
    this.triggerEl = element;

    const { content } = this.getParts(this.pop);
    content.textContent = message;

    this.position(this.pop, element);
    this.show(this.pop);
    this.bindGlobalListeners();
  }

  cleanup(result) {
    if (!this.pop) return;
    this.hide(this.pop);
    this.unbindGlobalListeners();
    const resolve = this._resolver;
    this._resolver = null;
    if (resolve) resolve(!!result);
  }

  // ──────────────────────────────────────────────
  // DOM helpers
  // ──────────────────────────────────────────────
  ensurePopover() {
    let el = document.getElementById("mv-confirm");
    if (el) return el;
    el = this.createPopover();
    document.body.appendChild(el);
    return el;
  }

  createPopover() {
    const el = document.createElement("div");
    el.id = "mv-confirm";
    el.className = "mv-confirm";
    Object.assign(el.style, {
      position: "fixed",
      top: "0",
      left: "0",
      transform: "translate(-9999px,-9999px)",
    });
    el.innerHTML = `
      <div class="mv-confirm__content"></div>
      <div class="mv-confirm__buttons">
        <button type="button" class="mv-btn mv-btn--sm mv-btn--negative mv-confirm__yes">Yes</button>
        <button type="button" class="mv-btn mv-btn--sm mv-btn--secondary mv-confirm__no">No</button>
      </div>
      <div class="mv-confirm__arrow"></div>`;
    return el;
  }

  getParts(pop) {
    return {
      content: pop.querySelector(".mv-confirm__content"),
      yes: pop.querySelector(".mv-confirm__yes"),
      no: pop.querySelector(".mv-confirm__no"),
    };
  }

  show(pop) {
    pop.setAttribute("data-show", "true");
  }

  hide(pop) {
    pop.removeAttribute("data-show");
    pop.style.transform = "translate(-9999px,-9999px)";
  }

  // ──────────────────────────────────────────────
  // Listeners
  // ──────────────────────────────────────────────
  bindGlobalListeners() {
    const { yes, no } = this.getParts(this.pop);

    this.onYes = () => this.cleanup(true);
    this.onNo = () => this.cleanup(false);
    this.onEsc = (e) => (e.key === "Escape" ? this.cleanup(false) : null);
    this.onOutside = (e) => {
      if (!this.pop.contains(e.target) && e.target !== this.triggerEl)
        this.cleanup(false);
    };
    this.onScrollOrResize = () => this.cleanup(false);

    yes.addEventListener("click", this.onYes);
    no.addEventListener("click", this.onNo);
    document.addEventListener("keydown", this.onEsc);
    document.addEventListener("click", this.onOutside, true);
    window.addEventListener("scroll", this.onScrollOrResize, true);
    window.addEventListener("resize", this.onScrollOrResize, true);
  }

  unbindGlobalListeners() {
    if (!this.pop) return;
    const { yes, no } = this.getParts(this.pop);

    yes.removeEventListener("click", this.onYes);
    no.removeEventListener("click", this.onNo);
    document.removeEventListener("keydown", this.onEsc);
    document.removeEventListener("click", this.onOutside, true);
    window.removeEventListener("scroll", this.onScrollOrResize, true);
    window.removeEventListener("resize", this.onScrollOrResize, true);

    this.onYes =
      this.onNo =
      this.onEsc =
      this.onOutside =
      this.onScrollOrResize =
        null;
  }

  // ──────────────────────────────────────────────
  // Positioning
  // ──────────────────────────────────────────────
  position(pop, element) {
    // Prep for measurement
    pop.style.opacity = "1";
    pop.style.transform = "translate(-9999px,-9999px)";

    const rect = element.getBoundingClientRect();
    const pr = pop.getBoundingClientRect();

    const { x, y, placement } = this.computePlacement(rect, pr);
    this.setPlacementClass(pop, placement);
    pop.style.transform = `translate(${Math.round(x)}px, ${Math.round(y)}px)`;
  }

  computePlacement(rect, pr) {
    const gap = this.gapValue;
    const margin = this.marginValue;
    const placements = ["bottom", "top", "right", "left"];

    for (const p of placements) {
      const { x, y } = this.coordsFor(p, rect, pr, gap);
      if (this.fits(p, x, y, pr, margin)) {
        return {
          x: this.clampX(x, pr, margin),
          y: this.clampY(y, pr, margin),
          placement: p,
        };
      }
    }

    // Fallback: bottom centered, clamped
    const fx = rect.left + (rect.width - pr.width) / 2;
    const fy = rect.bottom + gap;
    return {
      x: this.clampX(fx, pr, margin),
      y: this.clampY(fy, pr, margin),
      placement: "bottom",
    };
  }

  coordsFor(p, rect, pr, gap) {
    switch (p) {
      case "bottom":
        return {
          x: rect.left + (rect.width - pr.width) / 2,
          y: rect.bottom + gap,
        };
      case "top":
        return {
          x: rect.left + (rect.width - pr.width) / 2,
          y: rect.top - pr.height - gap,
        };
      case "right":
        return {
          x: rect.right + gap,
          y: rect.top + (rect.height - pr.height) / 2,
        };
      case "left":
        return {
          x: rect.left - pr.width - gap,
          y: rect.top + (rect.height - pr.height) / 2,
        };
      default:
        return { x: 0, y: 0 };
    }
  }

  fits(p, x, y, pr, margin) {
    switch (p) {
      case "bottom":
        return y + pr.height + margin <= window.innerHeight;
      case "top":
        return y >= margin;
      case "right":
        return x + pr.width + margin <= window.innerWidth;
      case "left":
        return x >= margin;
      default:
        return false;
    }
  }

  clampX(x, pr, margin) {
    return Math.max(margin, Math.min(x, window.innerWidth - pr.width - margin));
  }

  clampY(y, pr, margin) {
    return Math.max(
      margin,
      Math.min(y, window.innerHeight - pr.height - margin),
    );
  }

  setPlacementClass(pop, placement) {
    pop.classList.remove(
      "mv-confirm--top",
      "mv-confirm--right",
      "mv-confirm--bottom",
      "mv-confirm--left",
    );
    pop.classList.add(`mv-confirm--${placement}`);
  }
}
