/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.elements = document.querySelectorAll("turbo-frame");
    this.elements.forEach((el) => {
      el.addEventListener("turbo:before-fetch-request", this._addBusyAttribute);
      el.addEventListener("turbo:frame-load", this._removeBusyAttribute);
      el.addEventListener(
        "turbo:fetch-request-error",
        this._removeBusyAttribute,
      );
    });
  }

  disconnect() {
    this.elements.forEach((el) => {
      el.removeEventListener(
        "turbo:before-fetch-request",
        this._addBusyAttribute,
      );
      el.removeEventListener("turbo:frame-load", this._removeBusyAttribute);
      el.removeEventListener(
        "turbo:fetch-request-error",
        this._removeBusyAttribute,
      );
    });
  }

  _addBusyAttribute = (event) => {
    document.body.setAttribute("aria-busy", "true");
    document.body.setAttribute("busy", "");
    event.target.setAttribute("aria-busy", "true");
    event.target.setAttribute("busy", "");
  };

  _removeBusyAttribute = (event) => {
    document.body.removeAttribute("aria-busy");
    document.body.removeAttribute("busy");
    event.target.removeAttribute("aria-busy");
    event.target.removeAttribute("busy");
  };
}
