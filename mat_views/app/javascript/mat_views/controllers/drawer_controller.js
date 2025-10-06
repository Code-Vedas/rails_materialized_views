/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/**
 * Stimulus Controller: DrawerController
 * -------------------------------------
 * Controls a slide-in drawer backed by a Turbo Frame. Supports opening via
 * triggers, deep-linking with a query param, refreshing content, and handling
 * Turbo submission outcomes.
 *
 * Responsibilities:
 * - Open/close drawer; manage trigger stack for nested opens.
 * - Load frame content from trigger attributes or by name (router-style).
 * - Sync drawer state with a query parameter for deep links.
 * - Update header/title from loaded frame content.
 * - Handle Turbo events:
 *   - 299 → clear param + full page reload
 *   - 298 → close drawer
 *   - others → refresh active datatable
 *
 * Key Components:
 * - Public actions: `open`, `show`, `close`, `refresh`, `refreshActiveDatatable`, `refreshFrameById`, `openDrawerByName`, `load`
 * - Frame events: `_handleFrameLoad`, `_handleSubmitEnd`
 * - Helpers: `_installFrameListeners`, `_removeFrameListeners`, `_loadFromTrigger`,
 *            `_updateHeader`, `_hideDrawer`, `_rootElement`, `_handleEscape`,
 *            `_clearQueryParam`, `_setQueryParam`, `_openFromQueryParam`,
 *            `_openRun`, `_openPreferences`, `_openDefinition`
 */

import { Controller } from "@hotwired/stimulus";

/**
 * @class DrawerController
 * @extends Controller
 */
export default class extends Controller {
  /**
   * Targets:
   * - root: container element for the drawer (optional; falls back to this.element)
   * - overlay: backdrop element (optional)
   * - panel: the drawer panel (optional)
   * - frame: Turbo Frame inside the drawer
   * - header: header element (for aria-label updates)
   * - title: element for visible title text
   */
  static targets = ["root", "overlay", "panel", "frame", "header", "title"];

  /**
   * CSS classes:
   * - open: toggled on the root to show/hide the drawer
   */
  static classes = ["open"];

  /**
   * Values:
   * - queryParam: name of the URL query parameter to reflect drawer state
   */
  static values = {
    queryParam: { type: String, default: "open" },
  };

  /**
   * Initialize internal state and bind handlers.
   * @return {void}
   */
  initialize() {
    this.currentTargetStack = [];
    this.triggerEl = null;
    this._handleEscape = this._handleEscape.bind(this);
    this._handleSubmitEnd = this._handleSubmitEnd.bind(this);
    this._handleFrameLoad = this._handleFrameLoad.bind(this);
  }

  /**
   * Lifecycle: connect
   * Installs frame listeners and opens drawer if query param is present.
   * @return {void}
   */
  connect() {
    this._installFrameListeners();
    this._openFromQueryParam();
  }

  /**
   * Lifecycle: disconnect
   * Removes listeners.
   * @return {void}
   */
  disconnect() {
    this._removeFrameListeners();
    document.removeEventListener("keydown", this._handleEscape);
  }

  // ── Public actions ───────────────────────────────────────────────

  /**
   * Opens the drawer for the current trigger (pushes onto trigger stack).
   * @param {Event} [event]
   * @return {void}
   */
  open(event) {
    if (event) {
      event.preventDefault();
      event.stopPropagation();
      if (event.stopImmediatePropagation) event.stopImmediatePropagation();
      if (event.currentTarget) {
        this.currentTargetStack.push(event.currentTarget);
        this.triggerEl = event.currentTarget;
      }
    }
    this._loadFromTrigger();
  }

  /**
   * Shows the drawer (adds open class, sets aria, enables ESC handler).
   * @return {void}
   */
  show() {
    document.addEventListener("keydown", this._handleEscape);
    const root = this._rootElement();
    root.classList.add(this.openClass);
    root.setAttribute("aria-hidden", "false");
    this.overlayTarget?.setAttribute("aria-hidden", "false");
  }

  /**
   * Closes the drawer. If there is a previous trigger on the stack,
   * it loads that trigger instead (nested/stacked draws).
   * @return {void}
   */
  close() {
    this.currentTargetStack.pop();
    this.triggerEl = this.currentTargetStack.at(-1) || null;

    if (this.triggerEl) {
      this._loadFromTrigger();
      return;
    }

    this._hideDrawer();
    this._clearQueryParam();
    if (this.hasFrameTarget) this.frameTarget.removeAttribute("src");
  }

  /**
   * Reloads the drawer frame if it has a `src`.
   * @return {void}
   */
  refresh() {
    if (this.frameTarget?.src) {
      this.load(this.frameTarget.src);
    }
  }

  /**
   * Dispatches a datatable refresh event for the active page.
   * @return {void}
   */
  refreshActiveDatatable() {
    // First notify the Turbo Frame Lifecycle controller to flush busy states
    // in case any datatables were affected by the drawer action.
    // Subsiquently, turbo_frame_lifecycle_controller.js will notify datatables.
    document.dispatchEvent(
      new CustomEvent("drawer:refresh", {
        bubbles: false,
        cancelable: false,
      }),
    );
  }

  /**
   * Hard-refreshes a Turbo Frame by id, cache-busting with a timestamp param.
   * @param {string} id
   * @return {void}
   */
  refreshFrameById(id) {
    const frame = document.getElementById(id);
    if (!frame) return;
    const src = frame.getAttribute("src") || frame.dataset.src;
    if (!src) return;

    try {
      const url = new URL(src, window.location.href);
      url.searchParams.set("_", Date.now().toString());
      frame.src = url.toString();
    } catch {
      const separator = src.includes("?") ? "&" : "?";
      frame.src = `${src}${separator}_=${Date.now()}`;
    }
  }

  /**
   * Opens a drawer route by a logical name (e.g., "definitions_new_",
   * "definitions_view_42", "preferences_edit_", "runs_view_123").
   * @param {string} name - Pattern: "<type>_<action>_<id?>"
   * @return {void}
   */
  openDrawerByName(name) {
    if (!name) return;
    const [type, action, id] = name.split("_");
    switch (type) {
      case "definitions":
        this._openDefinition(action, id);
        break;
      case "runs":
        this._openRun(action, id);
        break;
      case "preferences":
        this._openPreferences(action);
        break;
      default:
    }
  }

  /**
   * Loads a URL into the drawer’s Turbo Frame.
   * @param {string} url
   * @return {void}
   */
  load(url) {
    if (!this.hasFrameTarget || !url) return;
    try {
      const resolved = new URL(url, window.location.href);
      this.frameTarget.src = resolved.toString();
    } catch {
      this.frameTarget.src = url;
    }
  }

  // ── Frame events ─────────────────────────────────────────────────

  /**
   * Handles Turbo frame load: updates title and sets deep-link param if present.
   * Expects hidden inputs inside the frame:
   * - #mv-drawer-title-text
   * - #mv-drawer-open-url-identifier
   * @param {Event} event
   * @return {void}
   */
  _handleFrameLoad(event) {
    const frame = event.target;
    const title = frame?.querySelector("#mv-drawer-title-text")?.value;
    if (title) this._updateHeader(title);

    const identifier = frame?.querySelector(
      "#mv-drawer-open-url-identifier",
    )?.value;
    if (identifier) this._setQueryParam(identifier);
  }

  /**
   * Handles Turbo submit-end results for drawer forms.
   * Status codes:
   * - 299: Clear param and full reload.
   * - 298: Close drawer.
   * - otherwise: refresh active datatable.
   * @param {CustomEvent} event
   * @return {void}
   */
  _handleSubmitEnd(event) {
    const statusCode = event.detail.fetchResponse.statusCode;
    if (statusCode === 299) {
      this._clearQueryParam();
      window.location.reload();
      return;
    }
    if (statusCode === 298) {
      this.close();
      this.refreshActiveDatatable();
    }
  }

  // ── Internal helpers ────────────────────────────────────────────

  /**
   * Attaches Turbo event listeners to the drawer frame.
   * @return {void}
   */
  _installFrameListeners() {
    if (!this.hasFrameTarget) return;
    this.frameTarget.addEventListener(
      "turbo:submit-end",
      this._handleSubmitEnd,
    );
    this.frameTarget.addEventListener(
      "turbo:frame-load",
      this._handleFrameLoad,
    );
  }

  /**
   * Removes Turbo event listeners from the drawer frame.
   * @return {void}
   */
  _removeFrameListeners() {
    if (!this.hasFrameTarget) return;
    this.frameTarget.removeEventListener(
      "turbo:submit-end",
      this._handleSubmitEnd,
    );
    this.frameTarget.removeEventListener(
      "turbo:frame-load",
      this._handleFrameLoad,
    );
  }

  /**
   * Loads URL/title from the top-of-stack trigger and opens the drawer.
   * Trigger attributes:
   * - data-drawer-title / title / aria-label → title
   * - data-drawer-url / href → URL
   * @return {void}
   */
  _loadFromTrigger() {
    const trigger = this.currentTargetStack.at(-1);
    if (!trigger) return;

    const title =
      trigger.dataset.drawerTitle ||
      trigger.getAttribute("title") ||
      trigger.getAttribute("aria-label") ||
      "";
    const url =
      trigger.dataset.drawerUrl || trigger.getAttribute("href") || null;

    if (!url || url === "#" || url.startsWith("javascript")) return;

    this._updateHeader(title);
    this.show();
    this.load(url);
  }

  /**
   * Updates header aria-label and visible title (if present).
   * @param {string} title
   * @return {void}
   */
  _updateHeader(title) {
    if (!this.hasHeaderTarget) return;
    this.headerTarget.setAttribute("aria-label", title || "");
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = title || "";
    }
  }

  /**
   * Hides the drawer and overlay, removes ESC handler, and blurs focus.
   * @return {void}
   */
  _hideDrawer() {
    document.removeEventListener("keydown", this._handleEscape);
    const root = this._rootElement();
    root.classList.remove(this.openClass);
    root.setAttribute("aria-hidden", "true");
    if (this.hasOverlayTarget) {
      this.overlayTarget.setAttribute("aria-hidden", "true");
    }
    document.activeElement?.blur();
    document.body.focus();
  }

  /**
   * Resolves the root element: `rootTarget` if present, otherwise controller element.
   * @return {HTMLElement}
   */
  _rootElement() {
    return this.hasRootTarget ? this.rootTarget : this.element;
  }

  /**
   * Closes the drawer on Escape key.
   * @param {KeyboardEvent} event
   * @return {void}
   */
  _handleEscape(event) {
    if (event.key === "Escape") this.close();
  }

  /**
   * Clears the deep-link query param.
   * @return {void}
   */
  _clearQueryParam() {
    const url = new URL(window.location.href);
    url.searchParams.delete(this.queryParamValue);
    history.replaceState({}, "", url);
  }

  /**
   * Sets the deep-link query param to `value`.
   * @param {string} value
   * @return {void}
   */
  _setQueryParam(value) {
    const url = new URL(window.location.href);
    url.searchParams.set(this.queryParamValue, value);
    history.replaceState({}, "", url);
  }

  /**
   * Opens the drawer from the current page’s query param (if present).
   * @return {void}
   */
  _openFromQueryParam() {
    const param = new URLSearchParams(window.location.search).get(
      this.queryParamValue,
    );
    if (param) this.openDrawerByName(param);
  }

  /**
   * Opens a run in view mode.
   * @param {string} action - expected "view"
   * @param {string|number} id
   * @return {void}
   */
  _openRun(action, id) {
    if (action !== "view") return;
    this._updateHeader("");
    this.show();
    this.load(`${window.MatViewsRoutes.runsPath}/${id}?frame_id=mv-drawer`);
  }

  /**
   * Opens preferences in edit mode.
   * @param {string} action - expected "edit"
   * @return {void}
   */
  _openPreferences(action) {
    if (action !== "edit") return;
    this._updateHeader("");
    this.show();
    this.load(`${window.MatViewsRoutes.preferencesPath}?frame_id=mv-drawer`);
  }

  /**
   * Opens a definition in new/view/edit mode based on `action`.
   * @param {"new"|"view"|"edit"} action
   * @param {string|number} id
   * @return {void}
   */
  _openDefinition(action, id) {
    this._updateHeader("");
    switch (action) {
      case "new":
        this.show();
        this.load(
          `${window.MatViewsRoutes.definitionsPath}/new?frame_id=mv-drawer`,
        );
        break;
      case "view":
        this.show();
        this.load(
          `${window.MatViewsRoutes.definitionsPath}/${id}?frame_id=mv-drawer`,
        );
        break;
      case "edit":
        this.show();
        this.load(
          `${window.MatViewsRoutes.definitionsPath}/${id}/edit?frame_id=mv-drawer`,
        );
        break;
      default:
    }
  }
}
