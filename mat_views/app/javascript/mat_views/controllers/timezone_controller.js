/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    if (document.cookie.indexOf(`browser_tz=${tz}`) === -1) {
      document.cookie = `browser_tz=${tz}; path=/`;
    }
  }
}
