/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/**
 * Stimulus Controller: TooltipController
 * --------------------------------------
 * Displays a lightweight, accessible tooltip near the trigger element with
 * viewport-aware placement, hover/focus/touch interactions, and delayed show/hide.
 *
 * Responsibilities:
 * - Render a single reusable tooltip element (`#mv-tooltip`) in the DOM.
 * - Show/hide on mouse/keyboard/touch with small delays to avoid flicker.
 * - Compute placement (top/right/bottom/left) with clamping to viewport.
 * - Manage ARIA (`aria-describedby`) and avoid the native browser tooltip.
 *
 * Key Components:
 * - Public actions: `show`, `hide`, `toggle`, `forceHide`
 * - Internals (show/hide): `_actuallyShow`, `_actuallyHide`
 * - Listeners: `_bindHandlers`, `_addListeners`, `_removeListeners`
 * - DOM helpers: `_ensureTooltipEl`, `_prepareForMeasure`, `_applyPlacementClass`,
 *                `_removeAllPlacementClasses`, `_setTransform`, `_offscreen`,
 *                `_setVisible`, `_setDescribedBy`, `_clearDescribedBy`
 * - Data/title: `_resolveText`, `_resolvePlacement`, `_saveAndRemoveTitle`, `_restoreTitle`
 * - Timers: `_schedule`, `_clearTimer`, `_clearAllTimers`, `_isVisible`
 * - Geometry: `_computePosition`, `_coordsFor`, `_clampX`, `_clampY`
 *
 * Usage:
 * <button
 *   data-controller="tooltip"
 *   data-tooltip-text-value="Save"
 *   data-tooltip-placement="bottom"
 * >
 *   Save
 * </button>
 */

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  /**
   * Values:
   * - text: explicit tooltip text; falls back to aria-label or title.
   * - placement: preferred placement ("top" | "right" | "bottom" | "left").
   * - delay: ms before showing on hover/focus.
   * - hideDelay: ms before hiding after leave/blur.
   * - disabled: disable tooltip behavior when true.
   * - gap: pixel gap between trigger and tooltip.
   * - margin: minimum distance from viewport edges.
   */
  static values = {
    text: String,
    placement: { type: String, default: "top" },
    delay: { type: Number, default: 120 },
    hideDelay: { type: Number, default: 80 },
    disabled: { type: Boolean, default: false },
    gap: { type: Number, default: 8 },
    margin: { type: Number, default: 8 },
  };

  // ──────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────

  /**
   * Creates/locates the singleton tooltip, binds handlers, and installs listeners.
   * @return {void}
   */
  connect() {
    this.tooltipEl = this._ensureTooltipEl();
    this.contentEl = this.tooltipEl.querySelector(".mv-tooltip__content");
    this.element.classList.add("mv-cursor-pointer");
    this._bindHandlers();
    this._addListeners();
  }

  /**
   * Clears timers, removes listeners, restores native title, and ARIA cleanup.
   * @return {void}
   */
  disconnect() {
    this._clearAllTimers();
    this._removeListeners();
    this._restoreTitle();
    this._clearDescribedBy();
  }

  // ──────────────────────────────────────────────
  // Public actions
  // ──────────────────────────────────────────────

  /**
   * Schedules tooltip show after `delay`. Cancels pending hide.
   * @return {void}
   */
  show() {
    if (this.disabledValue) return;
    this._clearTimer("_hideTimer");
    this._schedule("_showTimer", () => this._actuallyShow(), this.delayValue);
  }

  /**
   * Schedules tooltip hide after `hideDelay`. Cancels pending show.
   * @return {void}
   */
  hide() {
    this._clearTimer("_showTimer");
    this._schedule(
      "_hideTimer",
      () => this._actuallyHide(),
      this.hideDelayValue,
    );
  }

  /**
   * Toggles visibility based on current state.
   * @return {void}
   */
  toggle() {
    this._isVisible() ? this.hide() : this.show();
  }

  /**
   * Immediately hides the tooltip and moves it offscreen (no delay).
   * @return {void}
   */
  forceHide() {
    this._clearAllTimers();
    this._actuallyHide(true);
  }

  // ──────────────────────────────────────────────
  // Internals: show/hide
  // ──────────────────────────────────────────────

  /**
   * Resolves text, removes native title, positions, and shows the tooltip.
   * @return {void}
   */
  _actuallyShow() {
    const text = this._resolveText();
    if (!text) return;

    // Remove native title to avoid default browser tooltip
    this._saveAndRemoveTitle();

    // Fill content
    this.contentEl.textContent = text;

    // Prep, place, show
    this._prepareForMeasure();
    const rect = this.element.getBoundingClientRect();
    const ttRect = this.tooltipEl.getBoundingClientRect();
    const placement = this._resolvePlacement();
    const { x, y } = this._computePosition(
      rect,
      ttRect,
      placement,
      this.gapValue,
      this.marginValue,
    );

    this._applyPlacementClass(placement);
    this._setTransform(x, y);
    this._setVisible(true);
    this._setDescribedBy();
  }

  /**
   * Hides tooltip; optionally skip transition and move offscreen immediately.
   * @param {boolean} [immediate=false]
   * @return {void}
   */
  _actuallyHide(immediate = false) {
    this._setVisible(false);

    if (immediate) {
      this._offscreen();
    } else {
      // Allow CSS transition to finish before moving offscreen (if not reopened)
      setTimeout(() => {
        if (!this._isVisible()) this._offscreen();
      }, 150);
    }

    this._restoreTitle();
    this._clearDescribedBy();
  }

  // ──────────────────────────────────────────────
  // Internals: listeners and handlers
  // ──────────────────────────────────────────────

  /**
   * Binds event handlers with correct `this`.
   * @return {void}
   */
  _bindHandlers() {
    this._onEnter = this.show.bind(this);
    this._onLeave = this.hide.bind(this);
    this._onFocus = this.show.bind(this);
    this._onBlur = this.hide.bind(this);
    this._onKey = (e) => {
      if (e.key === "Escape") this.forceHide();
    };
    this._onTouch = (e) => {
      e.preventDefault();
      this.show();
      this._clearTimer("_touchTimer");
      this._touchTimer = setTimeout(() => this.hide(), 1500);
    };
  }

  /**
   * Installs mouse/keyboard/touch listeners on the trigger element.
   * @return {void}
   */
  _addListeners() {
    const el = this.element;
    el.addEventListener("mouseenter", this._onEnter);
    el.addEventListener("mouseleave", this._onLeave);
    el.addEventListener("focus", this._onFocus);
    el.addEventListener("blur", this._onBlur);
    el.addEventListener("keydown", this._onKey);
    // preventDefault() requires passive: false
    el.addEventListener("touchstart", this._onTouch, { passive: false });
  }

  /**
   * Removes listeners installed by `_addListeners`.
   * @return {void}
   */
  _removeListeners() {
    const el = this.element;
    if (!el) return;
    el.removeEventListener("mouseenter", this._onEnter);
    el.removeEventListener("mouseleave", this._onLeave);
    el.removeEventListener("focus", this._onFocus);
    el.removeEventListener("blur", this._onBlur);
    el.removeEventListener("keydown", this._onKey);
    el.removeEventListener("touchstart", this._onTouch, { passive: false });
  }

  // ──────────────────────────────────────────────
  // Internals: DOM helpers
  // ──────────────────────────────────────────────

  /**
   * Ensures a single reusable tooltip element exists in the document.
   * @return {HTMLElement}
   */
  _ensureTooltipEl() {
    let el = document.getElementById("mv-tooltip");
    if (el) return el;

    el = document.createElement("div");
    el.id = "mv-tooltip";
    el.setAttribute("role", "tooltip");
    el.className = "mv-tooltip";
    Object.assign(el.style, {
      position: "fixed",
      top: "0",
      left: "0",
      pointerEvents: "none",
      opacity: "0",
      transform: "translate(-9999px,-9999px)",
    });
    el.innerHTML =
      '<div class="mv-tooltip__content"></div><div class="mv-tooltip__arrow" data-arrow></div>';
    document.body.appendChild(el);
    return el;
  }

  /**
   * Prepares tooltip for measurement: hide, offscreen, remove placement classes.
   * @return {void}
   */
  _prepareForMeasure() {
    this.tooltipEl.style.opacity = "0";
    this._offscreen();
    this._removeAllPlacementClasses();
  }

  /**
   * Applies the placement modifier class (e.g., `mv-tooltip--top`).
   * @param {"top"|"right"|"bottom"|"left"} placement
   * @return {void}
   */
  _applyPlacementClass(placement) {
    this._removeAllPlacementClasses();
    this.tooltipEl.classList.add(`mv-tooltip--${placement}`);
  }

  /**
   * Removes all placement modifier classes.
   * @return {void}
   */
  _removeAllPlacementClasses() {
    this.tooltipEl.classList.remove(
      "mv-tooltip--top",
      "mv-tooltip--right",
      "mv-tooltip--bottom",
      "mv-tooltip--left",
    );
  }

  /**
   * Applies a CSS transform to move the tooltip to (x, y).
   * @param {number} x
   * @param {number} y
   * @return {void}
   */
  _setTransform(x, y) {
    this.tooltipEl.style.transform = `translate(${x}px, ${y}px)`;
  }

  /**
   * Moves the tooltip offscreen.
   * @return {void}
   */
  _offscreen() {
    this.tooltipEl.style.transform = "translate(-9999px,-9999px)";
  }

  /**
   * Toggles visibility via opacity/data attribute (for CSS transitions).
   * @param {boolean} visible
   * @return {void}
   */
  _setVisible(visible) {
    /* radarlint-js ignore-next-line */
    if (visible) {
      this.tooltipEl.style.opacity = "1";
      this.tooltipEl.setAttribute("data-show", "true");
    } else {
      this.tooltipEl.removeAttribute("data-show");
      this.tooltipEl.style.opacity = "0";
    }
  }

  /**
   * Adds `aria-describedby` to the trigger to reference the tooltip.
   * @return {void}
   */
  _setDescribedBy() {
    this.element.setAttribute("aria-describedby", "mv-tooltip");
  }

  /**
   * Removes `aria-describedby` from the trigger.
   * @return {void}
   */
  _clearDescribedBy() {
    this.element.removeAttribute("aria-describedby");
  }

  // ──────────────────────────────────────────────
  // Internals: data/text/title
  // ──────────────────────────────────────────────

  /**
   * Returns tooltip text from value, aria-label, or title attribute.
   * @return {string|undefined}
   */
  _resolveText() {
    return (
      this.textValue ||
      this.element.getAttribute("aria-label") ||
      this.element.getAttribute("title")
    );
  }

  /**
   * Returns desired placement from data attribute or value.
   * @return {"top"|"right"|"bottom"|"left"}
   */
  _resolvePlacement() {
    return (
      this.element.getAttribute("data-tooltip-placement") || this.placementValue
    );
  }

  /**
   * Saves and removes native title to suppress browser tooltip.
   * @return {void}
   */
  _saveAndRemoveTitle() {
    if (this.element.hasAttribute("title")) {
      this._savedTitle = this.element.getAttribute("title");
      this.element.removeAttribute("title");
    }
  }

  /**
   * Restores the saved native title after hiding.
   * @return {void}
   */
  _restoreTitle() {
    if (this._savedTitle) {
      this.element.setAttribute("title", this._savedTitle);
      this._savedTitle = null;
    }
  }

  // ──────────────────────────────────────────────
  // Internals: timers & state helpers
  // ──────────────────────────────────────────────

  /**
   * Schedules a `setTimeout` under a named slot, clearing any existing one.
   * @param {string} name
   * @param {Function} fn
   * @param {number} ms
   * @return {void}
   */
  _schedule(name, fn, ms) {
    this._clearTimer(name);
    this[name] = setTimeout(fn, ms);
  }

  /**
   * Clears a named timeout if present.
   * @param {string} name
   * @return {void}
   */
  _clearTimer(name) {
    if (this[name]) {
      clearTimeout(this[name]);
      this[name] = null;
    }
  }

  /**
   * Clears all internal timers.
   * @return {void}
   */
  _clearAllTimers() {
    this._clearTimer("_showTimer");
    this._clearTimer("_hideTimer");
    this._clearTimer("_touchTimer");
  }

  /**
   * Returns true when tooltip is currently visible.
   * @return {boolean}
   */
  _isVisible() {
    return this.tooltipEl?.getAttribute("data-show") === "true";
  }

  // ──────────────────────────────────────────────
  // Geometry
  // ──────────────────────────────────────────────

  /**
   * Computes final (x,y) with clamping for viewport edges.
   * @param {DOMRect} targetRect
   * @param {DOMRect} ttRect
   * @param {"top"|"right"|"bottom"|"left"} placement
   * @param {number} gap
   * @param {number} margin
   * @return {{x:number, y:number}}
   */
  _computePosition(targetRect, ttRect, placement, gap, margin) {
    const coords = this._coordsFor(placement, targetRect, ttRect, gap);
    const x = this._clampX(coords.x, ttRect.width, margin);
    const y = this._clampY(coords.y, ttRect.height, margin);
    return { x: Math.round(x), y: Math.round(y) };
  }

  /**
   * Calculates raw (x,y) for a given placement before clamping.
   * @param {"top"|"right"|"bottom"|"left"} placement
   * @param {DOMRect} r
   * @param {DOMRect} tt
   * @param {number} gap
   * @return {{x:number, y:number}}
   */
  _coordsFor(placement, r, tt, gap) {
    switch (placement) {
      case "top":
        return {
          x: r.left + (r.width - tt.width) / 2,
          y: r.top - tt.height - gap,
        };
      case "bottom":
        return { x: r.left + (r.width - tt.width) / 2, y: r.bottom + gap };
      case "left":
        return {
          x: r.left - tt.width - gap,
          y: r.top + (r.height - tt.height) / 2,
        };
      case "right":
      default:
        return { x: r.right + gap, y: r.top + (r.height - tt.height) / 2 };
    }
  }

  /**
   * Clamps X to viewport with margin.
   * @param {number} x
   * @param {number} width
   * @param {number} margin
   * @return {number}
   */
  _clampX(x, width, margin) {
    return Math.max(margin, Math.min(x, window.innerWidth - width - margin));
  }

  /**
   * Clamps Y to viewport with margin.
   * @param {number} y
   * @param {number} height
   * @param {number} margin
   * @return {number}
   */
  _clampY(y, height, margin) {
    return Math.max(margin, Math.min(y, window.innerHeight - height - margin));
  }
}
