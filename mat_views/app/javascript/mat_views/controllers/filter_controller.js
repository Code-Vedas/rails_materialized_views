/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    const queryParams = this.element.dataset.queryParams;
    this.queryParamsArray = queryParams ? queryParams.split(",") : [];

    if (this.queryParamsArray.length === 0) {
      return;
    }

    const qs = new URLSearchParams(window.location.search);

    // return if qs params are equal to form values, this.queryParamsArray
    const allMatch = this.queryParamsArray.every((param) => {
      const formElement = this.element.querySelector(`[name="${param}"]`);
      if (!formElement) {
        return true; // skip if form element not found
      }
      const formValue = formElement.value || "";
      const qsValue = qs.get(param) || "";
      return formValue === qsValue;
    });

    if (allMatch) {
      return;
    }

    // set form values from qs params, this.queryParamsArray
    this.queryParamsArray.forEach((param) => {
      const formElement = this.element.querySelector(`[name="${param}"]`);
      if (!formElement) {
        return; // skip if form element not found
      }
      const qsValue = qs.get(param);
      if (qsValue !== null) {
        formElement.value = qsValue;
      } else {
        formElement.value = ""; // reset to empty if param not in URL
      }
    });

    this.element.requestSubmit();
  }

  reset() {
    const selects = this.element.querySelectorAll("select");
    selects.forEach((select) => {
      if (select.options.length > 0) {
        select.selectedIndex = 0;
      }
    });

    // remove this.queryParamsArray from URL
    const url = new URL(window.location);
    this.queryParamsArray.forEach((param) => {
      url.searchParams.delete(param);
    });
    window.history.replaceState({}, "", url);

    this.element.requestSubmit();
  }

  autoSubmit(event) {
    if (!event.target) {
      return;
    }
    if (!event.target.name) {
      return;
    }

    const argName = event.target.name;
    const argValue = event.target.value;

    const url = new URL(window.location);
    if (event.target.value == "") {
      url.searchParams.delete(argName);
    } else {
      url.searchParams.set(argName, argValue);
    }
    window.history.replaceState({}, "", url);
    this.element.requestSubmit();
  }
}
