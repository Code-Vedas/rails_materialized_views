/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/**
 * FrameLifecycleController
 * ------------------------
 * @classdesc Stimulus controller orchestrating Turbo Frame and Turbo Stream lifecycles.
 *
 * Responsibilities:
 * - Add datatable context headers to outgoing Turbo Frame requests.
 * - Show and clear a unified “busy” state on frames and <body>.
 * - Handle both frame navigations and streamed responses.
 * - Track multiple concurrent busy frames safely.
 *
 * Key Methods:
 * - `_handleBeforeFetch`, `_handleComplete`: frame navigation lifecycle.
 * - `_handleBeforeStreamRender`: stream render interception.
 * - `_setFrameBusy`, `_setBodyBusy`: visual busy state management.
 * - `_bindFrame`, `_unbindFrame`: frame event lifecycle binding.
 *
 * Events handled:
 * - `turbo:before-fetch-request`
 * - `turbo:frame-load`
 * - `turbo:fetch-request-error`
 * - `turbo:before-stream-render`
 */

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  /** @type {string[]} Stimulus targets: one or more <turbo-frame> elements to observe. */
  static targets = ["frame"];

  /** @type {string[]} CSS classes toggled on frames and <body> when busy. */
  static classes = ["busy"];

  /** @type {object} Configurable values (ARIA attribute name for busy state). */
  static values = {
    busyAttribute: { type: String, default: "aria-busy" },
  };

  // ────────────────────────────────────────────────────────────────
  // Initialization and Lifecycle
  // ────────────────────────────────────────────────────────────────

  /**
   * Initialize internal state and bind `this` for handlers.
   */
  initialize() {
    /** @type {Set<HTMLElement>} currently-busy frames */
    this._busyFrames = new Set();

    this._handleBeforeFetch = this._handleBeforeFetch.bind(this);
    this._handleComplete = this._handleComplete.bind(this);
    this._handleBeforeStreamRender = this._handleBeforeStreamRender.bind(this);
    this._flushBusyFrames = this._flushBusyFrames.bind(this);

    /** Symbol to temporarily store affected frames on a <turbo-stream>. */
    this._affectedKey = Symbol("mvAffectedFrames");
  }

  /**
   * Stimulus lifecycle: connect.
   * - Cache <body> reference.
   * - Bind Turbo events on all frames.
   * - Subscribe to global stream render event.
   */
  connect() {
    this.bodyElement = document.body;
    this.frameTargets.forEach((frame) => this._bindFrame(frame));
    document.addEventListener("drawer:refresh", this._flushBusyFrames);
    document.addEventListener(
      "turbo:before-stream-render",
      this._handleBeforeStreamRender,
    );
  }

  /**
   * Stimulus lifecycle: disconnect.
   * - Unbind frame listeners.
   * - Remove global stream listener.
   * - Clear busy state.
   */
  disconnect() {
    this.frameTargets.forEach((frame) => this._unbindFrame(frame));
    document.removeEventListener("drawer:refresh", this._flushBusyFrames);
    document.removeEventListener(
      "turbo:before-stream-render",
      this._handleBeforeStreamRender,
    );

    this._busyFrames.forEach((f) => this._setFrameBusy(f, false));
    this._busyFrames.clear();
    this._setBodyBusy(false);
  }

  /**
   * Stimulus callback: when a frame target connects.
   * @param {HTMLElement} frame
   */
  frameTargetConnected(frame) {
    this._bindFrame(frame);
  }

  /**
   * Stimulus callback: when a frame target disconnects.
   * @param {HTMLElement} frame
   */
  frameTargetDisconnected(frame) {
    this._unbindFrame(frame);
    this._busyFrames.delete(frame);
    if (this._busyFrames.size === 0) this._setBodyBusy(false);
  }

  // ────────────────────────────────────────────────────────────────
  // Turbo Frame Lifecycle Handlers
  // ────────────────────────────────────────────────────────────────

  /**
   * Handle outgoing Turbo Frame requests.
   * Adds datatable headers and marks frame busy.
   *
   * @param {CustomEvent} event turbo:before-fetch-request
   */
  _handleBeforeFetch(event) {
    const frame = /** @type {HTMLElement} */ (event.currentTarget);

    // Add datatable context headers
    const params = new URL(window.location).searchParams;
    event.detail.fetchOptions.headers["X-DtSearch"] =
      params.get("dtsearch") || "";
    event.detail.fetchOptions.headers["X-DtSort"] = params.get("dtsort") || "";
    event.detail.fetchOptions.headers["X-DtFilter"] =
      params.get("dtfilter") || "";
    event.detail.fetchOptions.headers["X-DtPage"] = params.get("dtpage") || "1";
    event.detail.fetchOptions.headers["X-DtPerPage"] =
      params.get("dtperpage") || "25";

    this._setFrameBusy(frame, true);
    this._setBodyBusy(true);
  }

  /**
   * Handle completed or failed Turbo Frame loads.
   *
   * @param {CustomEvent} event turbo:frame-load | turbo:fetch-request-error
   */
  _handleComplete(event) {
    const frame = /** @type {HTMLElement} */ (event.currentTarget);
    this._setFrameBusy(frame, false);
    if (this._busyFrames.size === 0) this._setBodyBusy(false);
  }

  // ────────────────────────────────────────────────────────────────
  // Turbo Stream Lifecycle Handlers
  // ────────────────────────────────────────────────────────────────

  /**
   * Clear all busy states.
   * Used when drawers or other UI elements may have interrupted frame loads.
   */
  _flushBusyFrames() {
    this._busyFrames.forEach((f) => this._setFrameBusy(f, false));
    this._busyFrames.clear();
    this._setBodyBusy(false);

    // Notify datatables to refresh, since now no frames are busy
    // and they may have been affected by the drawer action.
    document.dispatchEvent(
      new CustomEvent("datatable:refresh", {
        bubbles: false,
        cancelable: false,
      }),
    );
  }

  /**
   * Handle streamed updates (no frame navigation).
   * Marks affected frames busy before render and clears after.
   *
   * @param {CustomEvent} event turbo:before-stream-render
   */
  _handleBeforeStreamRender(event) {
    const streamEl = event.target; // <turbo-stream>
    const affected = this._framesAffectedByStream(streamEl);

    if (affected.length > 0) {
      affected.forEach((f) => this._setFrameBusy(f, true));
      this._setBodyBusy(true);
    }

    // Stash affected frames for cleanup
    streamEl[this._affectedKey] = affected;

    // Wrap the render function for post-render cleanup
    const originalRender = event.detail.render;
    event.detail.render = (el) => {
      try {
        originalRender(el);
      } finally {
        const frames = streamEl[this._affectedKey] || [];
        frames.forEach((f) => this._setFrameBusy(f, false));
        delete streamEl[this._affectedKey];
        if (this._busyFrames.size === 0) this._setBodyBusy(false);
      }
    };
  }

  /**
   * Determine which frames a stream will affect.
   *
   * @param {HTMLElement} streamEl <turbo-stream> element
   * @return {HTMLElement[]} affected frames
   */
  _framesAffectedByStream(streamEl) {
    const targetId = streamEl.getAttribute("target");
    const targetsSelector = streamEl.getAttribute("targets");
    const out = new Set();

    // target="id"
    if (targetId) {
      const el = document.getElementById(targetId);
      const frame = el
        ? el.tagName === "TURBO-FRAME"
          ? el
          : el.closest("turbo-frame")
        : null;
      if (frame && this._isManagedFrame(frame)) out.add(frame);
    }

    // targets="selector"
    if (targetsSelector) {
      document.querySelectorAll(targetsSelector).forEach((node) => {
        const frame = node.closest("turbo-frame");
        if (frame && this._isManagedFrame(frame)) out.add(frame);
      });
    }

    return Array.from(out);
  }

  // ────────────────────────────────────────────────────────────────
  // Binding Helpers
  // ────────────────────────────────────────────────────────────────

  /**
   * Attach Turbo lifecycle events to a frame.
   * @param {HTMLElement} frame
   */
  _bindFrame(frame) {
    if (frame.__mvLifecycleBound) return;
    frame.addEventListener(
      "turbo:before-fetch-request",
      this._handleBeforeFetch,
    );
    frame.addEventListener("turbo:frame-load", this._handleComplete);
    frame.addEventListener("turbo:fetch-request-error", this._handleComplete);
    frame.__mvLifecycleBound = true;
  }

  /**
   * Detach Turbo lifecycle events from a frame.
   * @param {HTMLElement} frame
   */
  _unbindFrame(frame) {
    if (!frame.__mvLifecycleBound) return;
    frame.removeEventListener(
      "turbo:before-fetch-request",
      this._handleBeforeFetch,
    );
    frame.removeEventListener("turbo:frame-load", this._handleComplete);
    frame.removeEventListener(
      "turbo:fetch-request-error",
      this._handleComplete,
    );
    delete frame.__mvLifecycleBound;
  }

  // ────────────────────────────────────────────────────────────────
  // Busy State Helpers
  // ────────────────────────────────────────────────────────────────

  /**
   * Determine if a frame belongs to this controller.
   * @param {HTMLElement} frame
   * @return {boolean}
   */
  _isManagedFrame(frame) {
    return this.frameTargets.includes
      ? this.frameTargets.includes(frame)
      : this.frameTargets.indexOf?.(frame) >= 0;
  }

  /**
   * Mark or unmark a frame as busy, coercing child elements to their frame.
   *
   * @param {HTMLElement} node - may be the frame or a child element.
   * @param {boolean} busy
   */
  _setFrameBusy(node, busy) {
    if (!node) return;

    // Normalize to the owning <turbo-frame>
    let frame =
      node.tagName === "TURBO-FRAME" ? node : node.closest?.("turbo-frame");
    if (!frame || !this._isManagedFrame(frame)) return;

    if (busy) {
      this._busyFrames.add(frame);
      frame.setAttribute(this.busyAttributeValue, "true");
      frame.setAttribute("busy", "");
      if (this.hasBusyClass) frame.classList.add(this.busyClass);
    } else {
      this._busyFrames.delete(frame);
      frame.removeAttribute(this.busyAttributeValue);
      frame.removeAttribute("busy");
      if (this.hasBusyClass) frame.classList.remove(this.busyClass);
    }
  }

  /**
   * Apply or clear busy indicators on <body>.
   *
   * @param {boolean} busy
   */
  _setBodyBusy(busy) {
    if (!this.bodyElement) return;

    if (busy) {
      this.bodyElement.setAttribute(this.busyAttributeValue, "true");
      this.bodyElement.setAttribute("busy", "");
      if (this.hasBusyClass) this.bodyElement.classList.add(this.busyClass);
    } else {
      this.bodyElement.removeAttribute(this.busyAttributeValue);
      this.bodyElement.removeAttribute("busy");
      if (this.hasBusyClass) this.bodyElement.classList.remove(this.busyClass);
    }
  }
}
