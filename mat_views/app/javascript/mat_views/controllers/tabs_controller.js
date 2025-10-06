/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/**
 * Stimulus Controller: TabsController
 * -----------------------------------
 * Manages an accessible tab interface with URL-synced state and lazy-loaded
 * Turbo Frames inside tab panels.
 *
 * Responsibilities:
 * - Toggle active tab link + associated panel by name.
 * - Sync current tab to a query param (default: `tab`) for deep-linking.
 * - Optionally lazy-load panel content via `<turbo-frame data-src="...">`.
 *
 * Key Components:
 * - Public: `show`, `showByName`
 * - Helpers: `_initialTabName`, `_queryParamPresent`, `_toggleLink`,
 *            `_ensureFrameLoaded`, `_updateUrl`
 */

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  /**
   * Targets:
   * - link: clickable tab links (require data-name)
   * - panel: tab panels (require data-name; set `hidden` when inactive)
   */
  static targets = ["link", "panel"];

  /**
   * Values:
   * - param: query param name to store active tab (default: "tab")
   * - defaultTab: fallback tab name when no query param exists
   */
  static values = {
    param: { type: String, default: "tab" },
    defaultTab: String,
  };

  /**
   * CSS classes:
   * - activeLink: applied to active tab link (fallback: 'mv-tab--on')
   */
  static classes = ["activeLink"];

  /**
   * Lifecycle: connect
   * Initializes active tab from query/default, updates URL if missing,
   * and ensures the initial panel frame is loaded.
   * @return {void}
   */
  connect() {
    const initialTab = this._initialTabName();

    if (!this._queryParamPresent()) {
      this._updateUrl(initialTab);
    }

    requestAnimationFrame(() => {
      if (initialTab) this.showByName(initialTab, false);
      else if (this.panelTargets[0])
        this._ensureFrameLoaded(this.panelTargets[0]);
    });
  }

  /**
   * Click handler for tab links.
   * @param {MouseEvent} event
   * @return {void}
   */
  show(event) {
    event.preventDefault();
    const name = event.currentTarget?.dataset.name;
    if (!name) return;
    this.showByName(name);
  }

  /**
   * Activates the tab & panel by logical name.
   * Optionally pushes state to the URL (replaceState).
   * Dispatches "tabs:changed" event with `{ name }`.
   * @param {string} name
   * @param {boolean} [pushState=true]
   * @return {void}
   */
  showByName(name, pushState = true) {
    if (!name) return;

    this.linkTargets.forEach((link) => {
      const isActive = link.dataset.name === name;
      this._toggleLink(link, isActive);
    });

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.name !== name;
    });

    const active = this.panelTargets.find(
      (panel) => panel.dataset.name === name,
    );
    if (active) this._ensureFrameLoaded(active);

    if (pushState) {
      this._updateUrl(name);
    }

    this.dispatch("changed", { detail: { name } });
  }

  // ── Helpers ──────────────────────────────────────────────────────

  /**
   * Determines the initial tab name from URL, value, or first link.
   * @return {string|undefined}
   */
  _initialTabName() {
    const qs = new URLSearchParams(window.location.search);
    const fromQuery = qs.get(this.paramValue);
    if (fromQuery) return fromQuery;
    if (this.hasDefaultTabValue) return this.defaultTabValue;
    return this.linkTargets[0]?.dataset.name;
  }

  /**
   * Returns true if the tab query param is present in the URL.
   * @return {boolean}
   */
  _queryParamPresent() {
    const qs = new URLSearchParams(window.location.search);
    return qs.has(this.paramValue);
  }

  /**
   * Toggles selected state on a tab link with ARIA updates.
   * Falls back to 'mv-tab--on' if no activeLinkClass is configured.
   * @param {HTMLElement} link
   * @param {boolean} isActive
   * @return {void}
   */
  _toggleLink(link, isActive) {
    if (this.hasActiveLinkClass) {
      link.classList.toggle(this.activeLinkClass, isActive);
    } else {
      link.classList.toggle("mv-tab--on", isActive);
    }
    link.setAttribute("aria-selected", isActive ? "true" : "false");
    link.tabIndex = isActive ? 0 : -1;
  }

  /**
   * If the active panel contains a Turbo Frame with data-src, sets its src once.
   * @param {HTMLElement} panel
   * @return {void}
   */
  _ensureFrameLoaded(panel) {
    const frame = panel.querySelector("turbo-frame");
    if (!frame) return;

    const src = frame.dataset.src;
    if (src) {
      frame.setAttribute("src", src);
    }
  }

  /**
   * Updates the URL to reflect the active tab and clears datatable params.
   * (Removes dtfilter/dtsort/dtsearch to avoid cross-tab leakage.)
   * @param {string} name
   * @return {void}
   */
  _updateUrl(name) {
    const url = new URL(window.location.href);
    url.searchParams.set(this.paramValue, name);
    url.searchParams.delete("dtfilter");
    url.searchParams.delete("dtsort");
    url.searchParams.delete("dtsearch");
    history.replaceState({}, "", url);
  }
}
