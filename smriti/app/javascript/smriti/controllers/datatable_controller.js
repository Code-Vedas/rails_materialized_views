/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/**
 * Stimulus Controller: DatatableController
 * ----------------------------------------
 * Headless datatable controller that manages search, multi-column sorting,
 * filter clauses, pagination, and Turbo Stream refreshes.
 *
 * Responsibilities:
 * - Keep URL query params in sync with datatable state (`dtsearch`, `dtsort`, `dtfilter`, `dtpage`, `dtperpage`).
 * - Debounce search input and trigger refreshes efficiently.
 * - Manage multi-column sort state and annotate sort order on headers.
 * - Build and load the Turbo Frame stream URL for server-rendered table updates.
 *
 * Key Components:
 * - Search: `onSearchInput`, `clearSearchInput`
 * - Sorting: `toggleSort`, `_syncSortParamsFromLocation`, `_serializeSortParams`, `_updateSortIcons`
 * - Filtering: `onFilterChange`
 * - Pagination: `goToPage`, `_placeDefaultPaginationParamsInLocation`
 * - Refresh & URL: `_refresh`, `_replaceLocationParam`, `_buildStreamSrc`
 */

import { Controller } from "@hotwired/stimulus";

/**
 * @class DatatableController
 * @extends Controller
 */
export default class extends Controller {
  /**
   * Stimulus targets used by this controller.
   * - th: header cells that toggle sort (data-key is required)
   * - searchInput: text input for search terms
   * - filterField: <select> elements that emit filter clauses
   */
  static targets = ["th", "searchInput", "filterField"];

  /**
   * Stimulus values used by this controller.
   * @property {string} indexUrl - Base index URL used to fetch Turbo Stream updates.
   * @property {number} perpageDefault - Default page size if not present in URL.
   */
  static values = {
    indexUrl: String,
    perpageDefault: { type: Number, default: 10 },
  };

  /** Separator for joining multiple param clauses (e.g., sort/filter). */
  paramsSeparator = ",";
  /** Separator between sort column and direction (e.g., "name:asc"). */
  sortDirSeparator = ":";
  /** Debounce duration (ms) for search input. */
  debounceTimeout = 500;

  /**
   * Lifecycle: connect
   * Binds refresh handler, initializes state from URL, updates icons, and triggers first refresh.
   * @return {void}
   */
  connect() {
    this._refresh = this._refresh.bind(this);
    document.addEventListener("datatable:refresh", this._refresh);
    this._searchTimeout = null;
    this.dtSortParams = [];
    this._frameListenersAttached = false;

    this._placeDefaultPaginationParamsInLocation();
    this._syncSortParamsFromLocation();
    this._updateSortIcons();
    this._refresh();
  }

  /**
   * Lifecycle: disconnect
   * Cleans up listeners and timers.
   * @return {void}
   */
  disconnect() {
    document.removeEventListener("datatable:refresh", this._refresh);
    clearTimeout(this._searchTimeout);
  }

  /**
   * Handles search input with debounce. Updates `dtsearch` and refreshes.
   * @param {InputEvent} event
   * @return {void}
   */
  onSearchInput(event) {
    const value = this.searchInputTarget.value.trim();
    clearTimeout(this._searchTimeout);
    this._searchTimeout = setTimeout(() => {
      this._replaceLocationParam("dtsearch", value);
      this._refresh();
    }, this.debounceTimeout);
  }

  /**
   * Clears the search input, removes `dtsearch`, and refreshes.
   * @param {MouseEvent} event
   * @return {void}
   */
  clearSearchInput(event) {
    event.preventDefault();
    this.searchInputTarget.value = "";
    clearTimeout(this._searchTimeout);
    this._replaceLocationParam("dtsearch", null);
    this._refresh();
  }

  /**
   * Cycles sort state for a header (asc → desc → off) and updates `dtsort`.
   * Supports multi-column sort by accumulating clauses.
   * @param {MouseEvent} event
   * @return {void}
   */
  toggleSort(event) {
    event.preventDefault();
    const th = event.target.closest("th");
    const key = th?.dataset.key;
    if (!key) return;

    const existing = this.dtSortParams.find((sort) => sort.col === key);
    if (existing) {
      if (existing.dir === "asc") {
        existing.dir = "desc";
      } else {
        this.dtSortParams = this.dtSortParams.filter(
          (sort) => sort.col !== key,
        );
      }
    } else {
      this.dtSortParams.push({ col: key, dir: "asc" });
    }

    this._replaceLocationParam("dtsort", this._serializeSortParams());
    this._updateSortIcons();
    this._refresh();
  }

  /**
   * Builds filter clauses from select targets and updates `dtfilter`.
   * Clause format: "<key>:<value>", joined by `paramsSeparator`.
   * @param {Event} _event
   * @return {void}
   */
  onFilterChange(_event) {
    const selects = this.filterFieldTargets;
    if (!selects || selects.length === 0) return;

    const filterClauses = [];
    selects.forEach((select) => {
      const key = select.dataset.key;
      const value = select.value;

      if (key && value && value != "no_filter") {
        filterClauses.push(`${key}:${value}`);
      }
    });

    const filterParam =
      filterClauses.length > 0
        ? filterClauses.join(this.paramsSeparator)
        : null;
    this._replaceLocationParam("dtfilter", filterParam);
    this._refresh();
  }

  /**
   * Navigates to a specific page and updates `dtpage`.
   * @param {MouseEvent} event
   * @return {void}
   */
  goToPage(event) {
    event.preventDefault();
    const page = event.currentTarget.dataset.page;
    if (!page) return;

    const pageNum = parseInt(page);
    if (isNaN(pageNum) || pageNum < 1) return;

    this._replaceLocationParam("dtpage", `${pageNum}`);
    this._refresh();
  }

  changePerPage(event) {
    const select = event.target;
    const perpage = select.value;
    if (!perpage) return;

    const perpageNum = parseInt(perpage);
    if (isNaN(perpageNum) || perpageNum < 1) return;

    this._replaceLocationParam("dtperpage", `${perpageNum}`);
    this._replaceLocationParam("dtpage", "1");
    this._refresh();
  }

  /**
   * Triggers a Turbo Frame reload with the computed stream URL.
   * @return {void}
   */
  _refresh() {
    const url = this._buildStreamSrc(this.indexUrlValue);
    this.element.closest("turbo-frame").src = url;
  }

  /**
   * Parses `dtsort` from window location and initializes `dtSortParams`.
   * @return {void}
   */
  _syncSortParamsFromLocation() {
    const qs = new URLSearchParams(window.location.search);
    const sortParam = qs.get("dtsort");
    if (!sortParam) return;

    this.dtSortParams = sortParam
      .split(this.paramsSeparator)
      .map((clause) => clause.split(this.sortDirSeparator))
      .filter(([col]) => col)
      .map(([col, dir]) => ({
        col,
        dir: dir?.toLowerCase() === "desc" ? "desc" : "asc",
      }));
  }

  /**
   * Replaces or removes a query param in the current URL without reloading.
   * If `value` is null/empty, the param is removed.
   * @param {string} key
   * @param {?string} value
   * @return {void}
   */
  _replaceLocationParam(key, value) {
    const url = new URL(window.location);
    url.searchParams.delete(key);
    if (value && value.length > 0) {
      url.search += `&${key}=${value}`;
    }
    window.history.replaceState({}, "", url);
  }

  /**
   * Serializes `dtSortParams` into the `dtsort` query value.
   * Example: "name:asc,created_at:desc"
   * @return {?string}
   */
  _serializeSortParams() {
    if (!this.dtSortParams.length) return null;
    return this.dtSortParams
      .map((sort) => `${sort.col}${this.sortDirSeparator}${sort.dir}`)
      .join(this.paramsSeparator);
  }

  /**
   * Updates header sort icons and annotations to reflect `dtSortParams`.
   * Shows numeric annotations when multiple columns are sorted.
   * @return {void}
   */
  _updateSortIcons() {
    this.thTargets.forEach((th) => {
      const sortNeutral = th.querySelector(".mv-icon.sort-neutral");
      const sortAsc = th.querySelector(".mv-icon.sort-asc");
      const sortDesc = th.querySelector(".mv-icon.sort-desc");
      const annotation = th.querySelector(".mv-annotation");
      sortNeutral?.classList.remove("hidden");
      sortAsc?.classList.add("hidden");
      sortDesc?.classList.add("hidden");
      annotation?.classList.add("hidden");
    });

    const showAnnotation = this.dtSortParams.length > 1;
    this.dtSortParams.forEach((sort, index) => {
      const th = this.thTargets.find(
        (target) => target.dataset.key === sort.col,
      );
      if (!th) return;

      const sortNeutral = th.querySelector(".mv-icon.sort-neutral");
      const sortAsc = th.querySelector(".mv-icon.sort-asc");
      const sortDesc = th.querySelector(".mv-icon.sort-desc");
      const annotation = th.querySelector(".mv-annotation");

      sortNeutral?.classList.add("hidden");
      if (showAnnotation && annotation) {
        annotation.textContent = String(index + 1);
        annotation.classList.remove("hidden");
      } else {
        annotation?.classList.add("hidden");
      }

      if (sort.dir === "asc") {
        sortAsc?.classList.remove("hidden");
        sortDesc?.classList.add("hidden");
      } else {
        sortAsc?.classList.add("hidden");
        sortDesc?.classList.remove("hidden");
      }
    });
  }

  /**
   * Builds the Turbo Stream URL by merging datatable params from the current page.
   * Always appends `stream=true` to force stream rendering server-side.
   * @param {string} baseSrc
   * @return {string}
   */
  _buildStreamSrc(baseSrc) {
    const url = new URL(baseSrc, window.location.origin);
    const pageParams = new URLSearchParams(window.location.search);
    ["dtsearch", "dtsort", "dtfilter", "dtpage", "dtperpage"].forEach(
      (param) => {
        if (pageParams.has(param)) {
          url.searchParams.set(param, pageParams.get(param));
        } else {
          url.searchParams.delete(param);
        }
      },
    );
    url.searchParams.set("stream", "true");
    return url.toString();
  }

  /**
   * Ensures the URL contains default pagination params (`dtpage`, `dtperpage`).
   * @return {void}
   */
  _placeDefaultPaginationParamsInLocation() {
    const url = new URL(window.location);
    const params = url.searchParams;
    let updated = false;

    if (!params.has("dtpage")) {
      params.set("dtpage", "1");
      updated = true;
    }

    if (!params.has("dtperpage")) {
      params.set("dtperpage", String(this.perpageDefaultValue));
      updated = true;
    }

    if (updated) {
      window.history.replaceState({}, "", url);
    }
  }
}
