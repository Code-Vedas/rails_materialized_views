# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module Smriti
  module Admin
    # Smriti::Admin::DashboardController
    # ------------------------------------
    # Controller for the Smriti admin dashboard.
    #
    # Responsibilities:
    # - Provides the landing page (`index`) for the admin interface.
    # - Authorizes access via {ApplicationController#authorize_smriti!}.
    # - Prepares placeholder metrics content (future: aggregated refresh metrics).
    #
    class DashboardController < ApplicationController
      # GET /:lang/admin
      #
      # Renders the admin dashboard. Currently sets a placeholder message
      # until metric aggregation is implemented.
      #
      # @return [void]
      def index
        authorize_smriti!(:view, :smriti_dashboard)
        @metrics_note = 'Metrics coming soon (see: Aggregate refresh metrics for reporting).'
      end
    end
  end
end
