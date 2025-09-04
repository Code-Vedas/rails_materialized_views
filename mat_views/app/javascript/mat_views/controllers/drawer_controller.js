/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["overlay", "panel", "frame"];
  static currentTargetStack = [];

  connect() {
    this._escHandler = (e) => {
      if (e.key === "Escape") this.close();
    };
    if (this.hasFrameTarget) {
      this._submitEndHandler = (e) => this.onSubmitEnd(e);
      this._frameLoadHandler = (e) => this.onFrameLoad(e);
      this.frameTarget.addEventListener(
        "turbo:submit-end",
        this._submitEndHandler,
      );
      this.frameTarget.addEventListener(
        "turbo:frame-load",
        this._frameLoadHandler,
      );
    }
  }

  disconnect() {
    if (this.hasFrameTarget) {
      this.frameTarget.removeEventListener(
        "turbo:submit-end",
        this._submitEndHandler,
      );
      this.frameTarget.removeEventListener(
        "turbo:frame-load",
        this._frameLoadHandler,
      );
    }
    document.removeEventListener("keydown", this._escHandler);
  }

  loadAndShow() {
    let currentTarget = this.currentTargetStack.at(-1);
    if (!currentTarget) return;

    const title =
      currentTarget?.dataset.drawerTitle ||
      currentTarget?.getAttribute("title") ||
      currentTarget?.getAttribute("aria-label");
    const url =
      currentTarget?.dataset.drawerUrl || currentTarget?.getAttribute("href");
    if (!url || url === "#" || url === "javascript:void(0);") return;

    const header = this._drawerHeader();
    header.setAttribute("aria-label", title);
    const titleEle = header.querySelector("h2");
    titleEle.textContent = title;
    this.show();
    this.load(url);
  }

  open(event) {
    if (!this.currentTargetStack) {
      this.currentTargetStack = [];
    }
    if (event) {
      event.preventDefault();
      event.stopPropagation();
      if (event.stopImmediatePropagation) event.stopImmediatePropagation();
    }
    this.currentTargetStack.push(event?.currentTarget);
    this.loadAndShow();
  }

  show() {
    const root = this._root();
    root?.classList.add("is-open");
    document.addEventListener("keydown", this._escHandler);
    root?.setAttribute("aria-hidden", "false");
  }

  close() {
    this.currentTargetStack.pop();
    if (this.currentTargetStack.length > 0) {
      this.loadAndShow();
      return;
    }

    const root = this._root();
    document.activeElement?.blur();
    document.body.focus();
    root?.classList.remove("is-open");
    document.removeEventListener("keydown", this._escHandler);
    root?.setAttribute("aria-hidden", "true");

    this.frameTarget.removeAttribute("src");
  }

  refresh() {
    if (this.frameTarget?.src) {
      this.load(this.frameTarget.src);
    }
  }

  load(url) {
    const frame = this.frameTarget;
    if (!frame) return;

    const u = new URL(url, window.location.href);
    frame.src = u.toString();
  }

  // ── Events ───────────────────────────────────────────────────────

  onFrameLoad(event) {
    // get title from hidden input if present
    const frame = event.target;
    const titleInput = frame?.querySelector("#mv-drawer-title-text")?.value;
    if (titleInput) {
      const header = this._drawerHeader();
      header.setAttribute("aria-label", titleInput);
      const titleEle = header.querySelector("h2");
      titleEle.textContent = titleInput;
    }
  }

  onSubmitEnd(event) {
    if (event.detail.fetchResponse.statusCode === 299) {
      window.location.reload();
      return;
    } else if (event.detail.fetchResponse.statusCode === 298) {
      this.close();
    }

    this.refreshActiveFrame();
  }

  // ── Helpers ──────────────────────────────────────────────────────

  refreshActiveFrame() {
    const activeTabAnchor = document.querySelector(".mv-tab.mv-tab--on");
    const dataName = activeTabAnchor?.dataset.name;
    const activePanel = document.querySelector(
      `[data-tabs-target="panel"][data-name="${dataName}"]`,
    );
    const activeTurboFrame = activePanel?.querySelector("turbo-frame");
    this.refreshFrameById(activeTurboFrame.id);
  }

  refreshFrameById(id) {
    const frame = document.getElementById(id);
    if (!frame) return;
    let url = frame.getAttribute("src") || frame.dataset.src;
    if (!url) return;
    try {
      const u = new URL(url, window.location.href);
      u.searchParams.set("_", Date.now().toString());
      frame.src = u.toString();
    } catch {
      const sep = url.includes("?") ? "&" : "?";
      frame.src = url + sep + "_=" + Date.now();
    }
  }

  _root() {
    return document.querySelector(".mv-drawer-root");
  }

  _drawerHeader() {
    return this._root()?.querySelector(".mv-drawer-head");
  }
}
