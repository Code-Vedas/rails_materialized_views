/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
import { Application } from "@hotwired/stimulus";
const application = Application.start();
window.Stimulus = application;
export { application };
