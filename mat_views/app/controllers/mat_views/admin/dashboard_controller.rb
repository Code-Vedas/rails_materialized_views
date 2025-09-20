# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Admin
    # MatViews::Admin::DashboardController
    # ------------------------------------
    # Controller for the MatViews admin dashboard.
    #
    # Responsibilities:
    # - Provides the landing page (`index`) for the admin interface.
    # - Authorizes access via {ApplicationController#authorize_mat_views!}.
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
        authorize_mat_views!(:read, :mat_views_dashboard)
        @metrics_note = 'Metrics coming soon (see: Aggregate refresh metrics for reporting).'
      end
    end
  end
end
