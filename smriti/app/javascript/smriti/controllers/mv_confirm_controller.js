/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/**
 * Stimulus Controller: ConfirmPopoverController
 * ---------------------------------------------
 * Replaces Turbo’s default confirm dialog with a lightweight, positioned
 * popover that supports keyboard/overlay dismissal and viewport-aware placement.
 *
 * Responsibilities:
 * - Hook into Turbo’s `config.forms.confirm` and `config.links.confirm`.
 * - Render a reusable popover with Yes/No buttons.
 * - Position the popover around the triggering element with clamping.
 * - Resolve a Promise<boolean> back to Turbo to continue/cancel the action.
 *
 * Key Components:
 * - Turbo hooks: `installConfirmHooks`, `uninstallConfirmHooks`, `confirm`, `hasTurbo`
 * - Lifecycle: `connect`, `disconnect`, `open`, `cleanup`
 * - DOM helpers: `ensurePopover`, `createPopover`, `getParts`, `show`, `hide`
 * - Listeners: `bindGlobalListeners`, `unbindGlobalListeners`
 * - Positioning: `position`, `computePlacement`, `coordsFor`, `fits`, `clampX`, `clampY`, `setPlacementClass`
 */

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  /**
   * Values:
   * - enabled: when false, do not install Turbo confirm hooks.
   * - gap: pixel gap between trigger and popover.
   * - margin: minimum margin from viewport edges.
   */
  static values = {
    enabled: { type: Boolean, default: true },
    gap: { type: Number, default: 8 },
    margin: { type: Number, default: 8 },
  };

  /**
   * Lifecycle: connect
   * Installs Turbo hooks if enabled.
   * @return {void}
   */
  connect() {
    if (!this.enabledValue) return;
    this.installConfirmHooks();
  }

  /**
   * Lifecycle: disconnect
   * Restores Turbo hooks and resolves any pending confirm cleanly.
   * @return {void}
   */
  disconnect() {
    this.uninstallConfirmHooks();
    this.cleanup(false);
  }

  // ──────────────────────────────────────────────
  // Turbo hook wiring
  // ──────────────────────────────────────────────

  /**
   * Installs a unified confirm handler for Turbo forms and links.
   * @return {void}
   */
  installConfirmHooks() {
    if (!this.hasTurbo()) return;
    this.prevFormsConfirm = window.Turbo.config.forms?.confirm;
    this.prevLinksConfirm = window.Turbo.config.links?.confirm;

    const handler = this.confirm.bind(this);
    if (window.Turbo.config.forms) window.Turbo.config.forms.confirm = handler;
    if (window.Turbo.config.links) window.Turbo.config.links.confirm = handler;
  }

  /**
   * Restores previously installed Turbo confirm handlers.
   * @return {void}
   */
  uninstallConfirmHooks() {
    if (!this.hasTurbo()) return;
    if (window.Turbo.config.forms)
      window.Turbo.config.forms.confirm = this.prevFormsConfirm;
    if (window.Turbo.config.links)
      window.Turbo.config.links.confirm = this.prevLinksConfirm;
  }

  /**
   * Returns true if Turbo configuration is available.
   * @return {boolean}
   */
  hasTurbo() {
    return !!window.Turbo?.config;
  }

  // ──────────────────────────────────────────────
  // Confirm entry point
  // ──────────────────────────────────────────────

  /**
   * Turbo confirm entry. Shows a popover and resolves to true/false.
   * Falls back to `window.confirm` if Turbo is unavailable.
   * @param {string} message
   * @param {HTMLElement} element
   * @return {Promise<boolean>}
   */
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

  /**
   * Opens the confirm popover near the triggering element.
   * @param {string} message
   * @param {HTMLElement} element
   * @return {void}
   */
  open(message, element) {
    this.pop = this.ensurePopover();
    this.triggerEl = element;

    const { content } = this.getParts(this.pop);
    content.textContent = message;

    this.position(this.pop, element);
    this.show(this.pop);
    this.bindGlobalListeners();
  }

  /**
   * Hides the popover, unbinds listeners, and resolves the pending Promise.
   * @param {boolean} result
   * @return {void}
   */
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

  /**
   * Ensures a single reusable popover exists in the DOM.
   * @return {HTMLElement}
   */
  ensurePopover() {
    let el = document.getElementById("mv-confirm");
    if (el) return el;
    el = this.createPopover();
    document.body.appendChild(el);
    return el;
  }

  /**
   * Creates the popover element structure (content, buttons, arrow).
   * @return {HTMLElement}
   */
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

  /**
   * Returns references to key elements inside the popover.
   * @param {HTMLElement} pop
   * @return {{content: HTMLElement, yes: HTMLButtonElement, no: HTMLButtonElement}}
   */
  getParts(pop) {
    return {
      content: pop.querySelector(".mv-confirm__content"),
      yes: pop.querySelector(".mv-confirm__yes"),
      no: pop.querySelector(".mv-confirm__no"),
    };
  }

  /**
   * Marks the popover visible (CSS-driven).
   * @param {HTMLElement} pop
   * @return {void}
   */
  show(pop) {
    pop.setAttribute("data-show", "true");
  }

  /**
   * Hides the popover and moves it off-screen.
   * @param {HTMLElement} pop
   * @return {void}
   */
  hide(pop) {
    pop.removeAttribute("data-show");
    pop.style.transform = "translate(-9999px,-9999px)";
  }

  // ──────────────────────────────────────────────
  // Listeners
  // ──────────────────────────────────────────────

  /**
   * Binds global listeners (clicks, esc, scroll/resize) and button clicks.
   * @return {void}
   */
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

  /**
   * Unbinds all previously attached listeners.
   * @return {void}
   */
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

  /**
   * Positions the popover relative to the triggering element.
   * @param {HTMLElement} pop
   * @param {HTMLElement} element
   * @return {void}
   */
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

  /**
   * Computes best placement (bottom/top/right/left) with clamping.
   * @param {DOMRect} rect - trigger rect
   * @param {DOMRect} pr - popover rect
   * @return {{x:number, y:number, placement:"bottom"|"top"|"right"|"left"}}
   */
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

  /**
   * Returns the (x,y) coordinates for a given placement.
   * @param {"bottom"|"top"|"right"|"left"} p
   * @param {DOMRect} rect
   * @param {DOMRect} pr
   * @param {number} gap
   * @return {{x:number, y:number}}
   */
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

  /**
   * Checks if the popover fits within viewport for a given placement.
   * @param {"bottom"|"top"|"right"|"left"} p
   * @param {number} x
   * @param {number} y
   * @param {DOMRect} pr
   * @param {number} margin
   * @return {boolean}
   */
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

  /**
   * Clamps X coordinate within viewport margins.
   * @param {number} x
   * @param {DOMRect} pr
   * @param {number} margin
   * @return {number}
   */
  clampX(x, pr, margin) {
    return Math.max(margin, Math.min(x, window.innerWidth - pr.width - margin));
  }

  /**
   * Clamps Y coordinate within viewport margins.
   * @param {number} y
   * @param {DOMRect} pr
   * @param {number} margin
   * @return {number}
   */
  clampY(y, pr, margin) {
    return Math.max(
      margin,
      Math.min(y, window.innerHeight - pr.height - margin),
    );
  }

  /**
   * Applies a placement modifier class to the popover element.
   * @param {HTMLElement} pop
   * @param {"bottom"|"top"|"right"|"left"} placement
   * @return {void}
   */
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
