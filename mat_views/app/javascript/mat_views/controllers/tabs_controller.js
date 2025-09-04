/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["link", "panel"];

  connect() {
    const qs = new URLSearchParams(window.location.search);
    const name = qs.get("tab") || this.linkTargets[0]?.dataset?.name;
    if (name) this.showByName(name, false);
    else if (this.panelTargets[0])
      this._ensureFrameLoaded(this.panelTargets[0]);
  }

  show(e) {
    e.preventDefault();
    const name = e.currentTarget.dataset.name;
    this.showByName(name, true);
  }

  showByName(name, pushState) {
    this.linkTargets.forEach((a) => {
      const on = a.dataset.name === name;
      a.classList.toggle("mv-tab--on", on);
      a.setAttribute("aria-selected", on ? "true" : "false");
    });

    this.panelTargets.forEach((p) => {
      p.hidden = p.dataset.name !== name;
    });

    const active = this.panelTargets.find((p) => p.dataset.name === name);
    if (active) this._ensureFrameLoaded(active);

    if (pushState) {
      const url = new URL(window.location);
      url.searchParams.set("tab", name);

      if (name == "definitions") {
        url.searchParams.delete("mat_view_definition_id");
        url.searchParams.delete("operation");
        url.searchParams.delete("status");
      }

      history.replaceState({}, "", url);
    }
  }

  _ensureFrameLoaded(panel) {
    const frame = panel.querySelector("turbo-frame");
    if (!frame) return;
    if (!frame.getAttribute("src")) {
      const src = frame.dataset.src;
      if (src) frame.setAttribute("src", src);
    }

    frame.reload();
  }
}
