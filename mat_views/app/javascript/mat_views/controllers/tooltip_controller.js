/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
import { Controller } from "@hotwired/stimulus";

/**
 * Usage:
 * <button
 *   data-controller="tooltip"
 *   data-tooltip-text-value="Save"
 *   data-tooltip-placement="bottom"
 * >
 *   Save
 * </button>
 */
export default class extends Controller {
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
  connect() {
    this.tooltipEl = this._ensureTooltipEl();
    this.contentEl = this.tooltipEl.querySelector(".mv-tooltip__content");
    this.element.classList.add("mv-cursor-pointer");
    this._bindHandlers();
    this._addListeners();
  }

  disconnect() {
    this._clearAllTimers();
    this._removeListeners();
    this._restoreTitle();
    this._clearDescribedBy();
  }

  // ──────────────────────────────────────────────
  // Public actions
  // ──────────────────────────────────────────────
  show() {
    if (this.disabledValue) return;
    this._clearTimer("_hideTimer");
    this._schedule("_showTimer", () => this._actuallyShow(), this.delayValue);
  }

  hide() {
    this._clearTimer("_showTimer");
    this._schedule(
      "_hideTimer",
      () => this._actuallyHide(),
      this.hideDelayValue,
    );
  }

  toggle() {
    this._isVisible() ? this.hide() : this.show();
  }

  forceHide() {
    this._clearAllTimers();
    this._actuallyHide(true);
  }

  // ──────────────────────────────────────────────
  // Internals: show/hide
  // ──────────────────────────────────────────────
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

  _prepareForMeasure() {
    this.tooltipEl.style.opacity = "0";
    this._offscreen();
    this._removeAllPlacementClasses();
  }

  _applyPlacementClass(placement) {
    this._removeAllPlacementClasses();
    this.tooltipEl.classList.add(`mv-tooltip--${placement}`);
  }

  _removeAllPlacementClasses() {
    this.tooltipEl.classList.remove(
      "mv-tooltip--top",
      "mv-tooltip--right",
      "mv-tooltip--bottom",
      "mv-tooltip--left",
    );
  }

  _setTransform(x, y) {
    this.tooltipEl.style.transform = `translate(${x}px, ${y}px)`;
  }

  _offscreen() {
    this.tooltipEl.style.transform = "translate(-9999px,-9999px)";
  }

  _setVisible(visible) {
    if (visible) {
      this.tooltipEl.style.opacity = "1";
      this.tooltipEl.setAttribute("data-show", "true");
    } else {
      this.tooltipEl.removeAttribute("data-show");
      this.tooltipEl.style.opacity = "0";
    }
  }

  _setDescribedBy() {
    this.element.setAttribute("aria-describedby", "mv-tooltip");
  }

  _clearDescribedBy() {
    this.element.removeAttribute("aria-describedby");
  }

  // ──────────────────────────────────────────────
  // Internals: data/text/title
  // ──────────────────────────────────────────────
  _resolveText() {
    return (
      this.textValue ||
      this.element.getAttribute("aria-label") ||
      this.element.getAttribute("title")
    );
  }

  _resolvePlacement() {
    return (
      this.element.getAttribute("data-tooltip-placement") || this.placementValue
    );
  }

  _saveAndRemoveTitle() {
    if (this.element.hasAttribute("title")) {
      this._savedTitle = this.element.getAttribute("title");
      this.element.removeAttribute("title");
    }
  }

  _restoreTitle() {
    if (this._savedTitle) {
      this.element.setAttribute("title", this._savedTitle);
      this._savedTitle = null;
    }
  }

  // ──────────────────────────────────────────────
  // Internals: timers & state helpers
  // ──────────────────────────────────────────────
  _schedule(name, fn, ms) {
    this._clearTimer(name);
    this[name] = setTimeout(fn, ms);
  }

  _clearTimer(name) {
    if (this[name]) {
      clearTimeout(this[name]);
      this[name] = null;
    }
  }

  _clearAllTimers() {
    this._clearTimer("_showTimer");
    this._clearTimer("_hideTimer");
    this._clearTimer("_touchTimer");
  }

  _isVisible() {
    return this.tooltipEl?.getAttribute("data-show") === "true";
  }

  // ──────────────────────────────────────────────
  // Geometry
  // ──────────────────────────────────────────────
  _computePosition(targetRect, ttRect, placement, gap, margin) {
    const coords = this._coordsFor(placement, targetRect, ttRect, gap);
    const x = this._clampX(coords.x, ttRect.width, margin);
    const y = this._clampY(coords.y, ttRect.height, margin);
    return { x: Math.round(x), y: Math.round(y) };
  }

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

  _clampX(x, width, margin) {
    return Math.max(margin, Math.min(x, window.innerWidth - width - margin));
  }

  _clampY(y, height, margin) {
    return Math.max(margin, Math.min(y, window.innerHeight - height - margin));
  }
}
