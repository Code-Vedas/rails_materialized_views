/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/**
 * Stimulus Controller: FlashController
 * ------------------------------------
 * Handles automatic and manual dismissal of flash messages or alerts.
 *
 * Responsibilities:
 * - Automatically removes flash after a configurable duration.
 * - Supports manual dismissal through a “click-to-dismiss” action.
 * - Applies an optional fade-out class before removal for smooth transition.
 *
 * Key Components:
 * - Public: `dismiss`
 * - Internal: `_scheduleRemoval`, `_clearTimer`, `_finalizeRemoval`
 */

import { Controller } from "@hotwired/stimulus";

/**
 * @class FlashController
 * @extends Controller
 */
export default class extends Controller {
  /**
   * Values:
   * - duration: how long (ms) before the flash auto-dismisses (default: 10 000).
   */
  static values = {
    duration: { type: Number, default: 10000 },
  };

  /**
   * CSS classes:
   * - dismiss: class applied before removal (e.g., fade-out transition).
   */
  static classes = ["dismiss"];

  /**
   * Lifecycle: connect
   * Starts the auto-removal timer.
   * @return {void}
   */
  connect() {
    this._scheduleRemoval();
  }

  /**
   * Lifecycle: disconnect
   * Clears pending timers when controller disconnects.
   * @return {void}
   */
  disconnect() {
    this._clearTimer();
  }

  /**
   * Manually dismisses the flash message (e.g., via close button).
   * Cancels any scheduled auto-removal and removes the element immediately.
   * @param {Event} [event]
   * @return {void}
   */
  dismiss(event) {
    if (event) event.preventDefault();
    this._clearTimer();
    this._finalizeRemoval();
  }

  // ── Internal helpers ────────────────────────────────────────────

  /**
   * Starts a timeout to remove the element after the configured duration.
   * Does nothing if duration ≤ 0.
   * @return {void}
   */
  _scheduleRemoval() {
    if (this.durationValue <= 0) return;
    this._timer = window.setTimeout(
      () => this._finalizeRemoval(),
      this.durationValue,
    );
  }

  /**
   * Cancels the scheduled removal timer.
   * @return {void}
   */
  _clearTimer() {
    if (this._timer) {
      clearTimeout(this._timer);
      this._timer = null;
    }
  }

  /**
   * Removes the flash element, optionally adding a dismiss animation class.
   * @return {void}
   */
  _finalizeRemoval() {
    if (this.hasDismissClass) {
      this.element.classList.add(this.dismissClass);
      window.setTimeout(() => this.element.remove(), 150);
    } else {
      this.element.remove();
    }
  }
}
