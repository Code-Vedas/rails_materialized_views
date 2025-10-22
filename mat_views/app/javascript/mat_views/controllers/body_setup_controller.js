/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/**
 * Stimulus Controller: ThemeAndTimezoneController
 * -----------------------------------------------
 * Manages browser timezone cookie and applied theme attributes.
 *
 * Responsibilities:
 * - Detects and stores the browser’s timezone in a cookie.
 * - Determines and applies the appropriate UI theme (light/dark)
 *   based on user setting or system preference.
 * - Ensures consistency between `data-theme` and `data-applied-theme`
 *   attributes on the `<html>` element.
 *
 * Key Components:
 * - Timezone: `_ensureTimezoneCookie`, `_cookieMatches`, `_writeCookie`
 * - Theme: `_ensureAppliedTheme`, `_applyTheme`
 */

import { Controller } from "@hotwired/stimulus";

/**
 * @class ThemeAndTimezoneController
 * @extends Controller
 */
export default class extends Controller {
  /**
   * Static values configuration for Stimulus values API.
   * @property {string} timezoneCookie - Name of the timezone cookie.
   * @property {string} timezoneCookiePath - Path for the timezone cookie.
   * @property {string} themeAttribute - Attribute containing desired theme.
   * @property {string} appliedThemeAttribute - Attribute to store applied theme.
   */
  static values = {
    timezoneCookie: { type: String, default: "browser_tz" },
    timezoneCookiePath: { type: String, default: "/" },
    themeAttribute: { type: String, default: "data-theme" },
    appliedThemeAttribute: { type: String, default: "data-applied-theme" },
  };

  /**
   * Initializes controller-level references.
   */
  initialize() {
    /** @type {HTMLElement} Root HTML element */
    this.htmlElement = document.documentElement;
  }

  /**
   * Called when the controller is connected to the DOM.
   * Ensures timezone and theme are properly set.
   */
  connect() {
    this._ensureTimezoneCookie();
    this._ensureAppliedTheme();
  }

  // ── Timezone ─────────────────────────────────────────────────────

  /**
   * Ensures that a cookie storing the browser's timezone is set.
   */
  _ensureTimezoneCookie() {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    if (this._cookieMatches(tz)) return;
    this._writeCookie(tz);
  }

  /**
   * Checks whether the stored cookie already matches the given value.
   * @param {string} value - Timezone string to check.
   * @return {boolean} True if cookie already matches.
   */
  _cookieMatches(value) {
    const needle = `${this.timezoneCookieValue}=${value}`;
    return document.cookie.split(";").some((entry) => entry.trim() === needle);
  }

  /**
   * Writes a cookie with the provided timezone value.
   * @param {string} value - Timezone value (e.g., "America/New_York").
   * @return {void}
   */
  _writeCookie(value) {
    document.cookie = `${this.timezoneCookieValue}=${value}; path=${this.timezoneCookiePathValue}`;
  }

  // ── Theme ────────────────────────────────────────────────────────

  /**
   * Ensures that the applied theme matches either a user preference
   * or the system’s color-scheme setting.
   */
  _ensureAppliedTheme() {
    const setting = this.htmlElement.getAttribute(this.themeAttributeValue);
    if (setting === "light" || setting === "dark") {
      this._applyTheme(setting);
      return;
    }

    const prefersDark = window.matchMedia(
      "(prefers-color-scheme: dark)",
    ).matches;
    this._applyTheme(prefersDark ? "dark" : "light");
  }

  /**
   * Applies a theme by updating the `data-applied-theme` attribute.
   * @param {"light" | "dark"} theme - Theme name to apply.
   * @return {void}
   */
  _applyTheme(theme) {
    this.htmlElement.setAttribute(this.appliedThemeAttributeValue, theme);
  }
}
