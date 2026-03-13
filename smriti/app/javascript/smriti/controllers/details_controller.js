/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/**
 * Stimulus Controller: DetailsDisclosureController
 * -----------------------------------------------
 * Smoothly animates a `<details>` element’s open/close behavior by
 * transitioning the height of an inner content wrapper.
 *
 * Responsibilities:
 * - Normalize initial open/closed state on connect (SSR/serverside toggles).
 * - Animate expand/collapse using CSS transitions on a single `height` property.
 * - Provide interruption handling to cancel/lock ongoing animations cleanly.
 *
 * Key Components:
 * - Public: `toggle`
 * - Internal: `_expand`, `_collapse`, `_cancelAnimation`, `_onTransitionEnd`
 * - Style helpers: `_setTransition`, `_setTransitionNone`, `_setHeight`, `_setHeightAuto`
 */

import { Controller } from "@hotwired/stimulus";

/**
 * @class DetailsDisclosureController
 * @extends Controller
 */
export default class extends Controller {
  /**
   * Targets:
   * - content: wrapper inside <details> whose height is animated.
   */
  static targets = ["content"];

  /**
   * Values:
   * - duration: animation duration in milliseconds.
   */
  static values = { duration: { type: Number, default: 200 } };

  /**
   * Lifecycle: connect
   * Normalizes initial state and prepares animation flags.
   * @return {void}
   */
  connect() {
    this.animating = false;
    // Normalize initial state (support SSR or toggled-by-server)
    if (this.element.open) {
      this._setHeightAuto();
    } else {
      this._setHeight(0);
    }
  }

  /**
   * Toggles the disclosure (expand if closed, collapse if open).
   * Cancels any in-flight animation before toggling.
   * @param {Event} event
   * @return {void}
   */
  toggle(event) {
    event.preventDefault();
    if (this.animating) this._cancelAnimation();

    if (this.element.open) {
      this._collapse();
    } else {
      this._expand();
    }
  }

  // ────────────────────────────────────────────────────────────────
  // internal
  // ────────────────────────────────────────────────────────────────

  /**
   * Animates expansion: set height from 0 → measured content height.
   * Keeps <details> open and resets to `height:auto` after transition.
   * @return {void}
   */
  _expand() {
    const el = this.contentTarget;
    this.animating = true;

    // Set starting point
    this._setTransitionNone();
    this._setHeight(0);
    // Make <details> open *before* measuring end height, so children are laid out.
    this.element.open = true;

    // Next frame: measure, then animate to end height
    requestAnimationFrame(() => {
      const end = el.scrollHeight;
      this._setTransition();
      this._setHeight(end);

      this._onTransitionEnd(() => {
        this._setHeightAuto(); // allow content to grow/shrink after expand
        this.animating = false;
      });
    });
  }

  /**
   * Animates collapse: lock current pixel height → 0, then close <details>.
   * @return {void}
   */
  _collapse() {
    const el = this.contentTarget;
    this.animating = true;

    // Freeze current height (auto → px) to start a smooth collapse
    this._setTransitionNone();
    const start = el.scrollHeight;
    this._setHeight(start);

    // Next frame: animate to 0, then close details
    requestAnimationFrame(() => {
      this._setTransition();
      this._setHeight(0);

      this._onTransitionEnd(() => {
        this.element.open = false;
        this._setTransitionNone();
        this._setHeight(0); // keep at 0 when closed
        this.animating = false;
      });
    });
  }

  /**
   * Cancels any ongoing transition and locks the current visual height.
   * Useful when rapidly toggling.
   * @return {void}
   */
  _cancelAnimation() {
    // Interrupt ongoing animation cleanly
    const el = this.contentTarget;
    const computed = parseFloat(getComputedStyle(el).height);
    this._setTransitionNone();
    this._setHeight(computed); // lock current visual height
    this.animating = false;
  }

  /**
   * Invokes callback after the height transition on the content target ends.
   * Filters unrelated transition events.
   * @param {Function} cb - Callback to run after transition end.
   * @return {void}
   */
  _onTransitionEnd(cb) {
    const el = this.contentTarget;
    const handler = (e) => {
      if (e.target !== el || e.propertyName !== "height") return;
      el.removeEventListener("transitionend", handler);
      el.removeEventListener("transitioncancel", handler);
      cb();
    };
    el.addEventListener("transitionend", handler, { once: false });
    el.addEventListener("transitioncancel", handler, { once: false });
  }

  /**
   * Applies the height transition using the configured duration.
   * @return {void}
   */
  _setTransition() {
    this.contentTarget.style.transition = `height ${this.durationValue}ms ease`;
  }

  /**
   * Disables the height transition for instantaneous style updates.
   * @return {void}
   */
  _setTransitionNone() {
    this.contentTarget.style.transition = "none";
  }

  /**
   * Sets the content wrapper height in pixels.
   * @param {number} px - Height in pixels.
   * @return {void}
   */
  _setHeight(px) {
    this.contentTarget.style.height = `${px}px`;
  }

  /**
   * Switches the content wrapper to natural height (`auto`).
   * @return {void}
   */
  _setHeightAuto() {
    this._setTransitionNone();
    this.contentTarget.style.height = "auto";
  }
}
