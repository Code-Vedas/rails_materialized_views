# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

Rails.application.routes.draw do
  mount MatViews::Engine => '/mat_views'
end
