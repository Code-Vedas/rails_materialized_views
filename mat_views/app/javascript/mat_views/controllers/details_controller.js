/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content"];
  static values = { duration: Number };

  connect() {
    this.animating = false;
    // Normalize initial state (support SSR or toggled-by-server)
    if (this.element.open) {
      this._setHeightAuto();
    } else {
      this._setHeight(0);
    }
  }

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

  _cancelAnimation() {
    // Interrupt ongoing animation cleanly
    const el = this.contentTarget;
    const computed = parseFloat(getComputedStyle(el).height);
    this._setTransitionNone();
    this._setHeight(computed); // lock current visual height
    this.animating = false;
  }

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

  _setTransition() {
    const ms = this.hasDurationValue ? this.durationValue : 200;
    this.contentTarget.style.transition = `height ${ms}ms ease`;
  }

  _setTransitionNone() {
    this.contentTarget.style.transition = "none";
  }

  _setHeight(px) {
    this.contentTarget.style.height = `${px}px`;
  }

  _setHeightAuto() {
    this._setTransitionNone();
    this.contentTarget.style.height = "auto";
  }
}
