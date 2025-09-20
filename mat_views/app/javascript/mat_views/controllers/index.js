/**
 * Copyright Codevedas Inc. 2025-present
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */
import { application } from "mat_views/controllers/application";
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading";

eagerLoadControllersFrom("mat_views/controllers", application);
