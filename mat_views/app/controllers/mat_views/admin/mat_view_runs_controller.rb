# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Admin
    # MatViews::Admin::MatViewRunsController
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
    class MatViewRunsController < ApplicationController
      include MatViews::Admin::DatatableHelper

      before_action :ensure_frame, :parse_headers_to_params
      helper_method :definition
      before_action :ensure_frame, only: %i[index show]
      before_action :set_mat_view_run, only: %i[show]

      # GET /:lang/admin/runs
      #
      # Two part rendering:
      # - Full page load when no `stream` param: renders index with datatable frame. This is
      #   essentially shell of the datatable for initial load.
      # - When shell is loaded, it requests the `stream` version which renders just the datatable rows
      #   and pagination controls. This allows for dynamic updates via Turbo Streams.
      #
      # @return [void]
      def index
        authorize_mat_views!(:read, :mat_views_runs)

        assign_index_state

        if params[:stream].present?
          render_dt_turbo_streams
        else
          render 'index', formats: :html, layout: 'mat_views/turbo_frame', locals: { row_meta: @row_meta }
        end
      end

      # GET /:lang/admin/runs/:id
      #
      # Displays details for a single run.
      #
      # @return [void]
      def show
        authorize_mat_views!(:read, :mat_views_run, @run)

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
      end

      # Loads data for the index datatable with filtering, searching, sorting, and pagination.
      # sets @data.
      #
      # @api private
      #
      # @return [void]
      def index_dt_load_data
        rel = MatViews::MatViewRun
        rel = dt_apply_filter(rel, index_dt_columns)
        rel = dt_apply_search(rel, index_dt_columns)
        rel = dt_apply_sort(rel, index_dt_columns)
        @data = dt_apply_pagination(rel, @dt_config[:pagination][:per_page_default])
      end

      # Configuration for the index datatable.
      #
      # @api private
      #
      # @return [Hash] datatable configuration
      def index_dt_config
        columns = index_dt_columns
        {
          id: 'mv-runs-table',
          index_url: admin_mat_view_runs_path(frame_id: @frame_id),
          frame_id: 'mv-runs-datatable',
          columns: columns,
          dt_humanize_ref: 'MatViews::MatViewRun',
          empty_row_partial_name: 'dt-index-empty-row',
          row_partial_name: 'dt-index-row',
          search_enabled: columns.any? { |_, col| col[:search].present? },
          filter_enabled: columns.any? { |_, col| col[:filter].present? },
          pagination: { per_page_default: 10, per_page_options: [10, 25, 50, 100] }
        }
      end

      # Column definitions for the index datatable.
      #
      # @api private
      #
      # @return [Hash] column definitions
      def index_dt_columns
        {
          operation: {
            label_ref: 'operation',
            label_type: 'humanize_attr',
            sort: 'operation',
            filter: 'operation',
            search: 'operation'
          },
          definition: {
            label_ref: 'definition',
            label_type: 'i18n',
            sort: 'definition',
            filter: 'definition',
            search: 'definition'
          },
          started_at: {
            label_ref: 'started_at',
            label_type: 'humanize_attr',
            sort: 'started_at',
            filter: nil,
            search: nil
          },
          status: {
            label_ref: 'status',
            label_type: 'humanize_attr',
            sort: 'status',
            filter: 'status',
            search: 'status'
          },
          duration: {
            label_ref: 'duration_ms',
            label_type: 'humanize_attr',
            filter: nil,
            sort: 'duration_ms',
            search: 'duration_ms'
          },
          rows_before_after: {
            label_ref: 'rows_before_after',
            label_type: 'humanize_attr',
            filter: nil,
            sort: nil,
            search: nil
          },
          details: {
            label_ref: 'details',
            label_type: 'humanize_attr',
            filter: nil,
            sort: nil,
            search: nil
          }
        }
      end

      # Assigns instance variables for the index action.
      #
      # @api private
      #
      # @return [void]
      def assign_index_state
        @dt_config = index_dt_config
        @data = []

        index_dt_load_data
        @row_meta = {}
      end
    end
  end
end
