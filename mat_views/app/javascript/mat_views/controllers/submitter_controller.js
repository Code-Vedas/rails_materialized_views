/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  submit() {
    this.element.disabled = true;
    this.element.classList.add("opacity-60");
    if (this.element.form) this.element.form.submit();
  }
}
