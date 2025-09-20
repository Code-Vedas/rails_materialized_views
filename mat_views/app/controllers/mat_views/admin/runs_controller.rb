# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Admin
    # MatViews::Admin::RunsController
    # -------------------------------
    # Controller for viewing materialised view run history in the admin UI.
    #
    # Responsibilities:
    # - Provides a list of recent runs (create/refresh/delete) for all definitions.
    # - Shows details for an individual run in a Turbo frame/drawer context.
    #
    # Filters:
    # - `before_action :ensure_frame` → enforces frame-only access.
    # - `before_action :set_mat_view_run` → loads and authorizes a single run.
    #
    # Views:
    # - Index renders `mat_views/admin/runs/embed_frame` partial.
    # - Show renders `mat_views/admin/runs/embed_show_drawer` partial.
    #
    class RunsController < ApplicationController
      before_action :ensure_frame
      helper_method :definition
      before_action :ensure_frame, only: %i[index show]
      before_action :set_mat_view_run, only: %i[show]

      # GET /:lang/admin/runs
      #
      # Lists all materialised view runs ordered by start time.
      #
      # @return [void]
      def index
        authorize_mat_views!(:read, :mat_views_runs)

        @definitions = MatViews::MatViewDefinition.order(:name).to_a
        @runs = MatViews::MatViewRun.order(started_at: :desc)

        %i[mat_view_definition_id operation status].each do |param|
          param_value = params[param]
          next unless param_value.present?

          @runs = @runs.where(param => param_value)
        end
        render 'index', formats: :html, layout: 'mat_views/turbo_frame'
      end

      # GET /:lang/admin/runs/:id
      #
      # Displays details for a single run.
      #
      # @return [void]
      def show
        render 'show', formats: :html, layout: 'mat_views/turbo_frame'
      end

      private

      # Loads the requested run and checks authorization.
      #
      # @api private
      #
      # @return [void]
      def set_mat_view_run
        @run = MatViews::MatViewRun.find(params[:id])
        authorize_mat_views!(:read, @run)
      end
    end
  end
end
