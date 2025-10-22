# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Admin
    # MatViews::Admin::MatViewDefinitionsController
    # ---------------------------------------------
    # Admin CRUD controller for {MatViews::MatViewDefinition} records.
    #
    # Responsibilities:
    # - Full CRUD lifecycle: index, show, new, create, edit, update, destroy.
    # - Admin-only actions to trigger materialised view operations:
    #   - {#create_now} → enqueues {MatViews::CreateViewJob}
    #   - {#refresh} → enqueues {MatViews::RefreshViewJob}
    #   - {#delete_now} → enqueues {MatViews::DeleteViewJob}
    # - Integrates with Turbo Frames (uses frame-aware redirects/responses).
    # - Normalizes array fields (`unique_index_columns`, `dependencies`) from
    #   comma-separated params into arrays.
    #
    # Filters:
    # - `before_action :set_definition` for member actions.
    # - `before_action :normalize_array_fields` for create/update.
    # - `before_action :ensure_frame` to enforce frame context.
    #
    class MatViewDefinitionsController < ApplicationController
      include MatViews::Admin::DatatableHelper

      before_action :set_definition, only: %i[show edit update destroy create_now refresh delete_now]
      before_action :normalize_array_fields, only: %i[create update]
      before_action :parse_headers_to_params, :ensure_frame

      # GET /:lang/admin/definitions
      #
      # Two part rendering:
      # - Full page load when no `stream` param: renders index with datatable frame. This is
      #   essentially shell of the datatable for initial load.
      # - When shell is loaded, it requests the `stream` version which renders just the datatable rows
      #   and pagination controls. This allows for dynamic updates via Turbo Streams.
      #
      # @return [void]
      def index
        authorize_mat_views!(:read, :mat_views_definitions)

        assign_index_state

        if params[:stream].present?
          render_dt_turbo_streams
          return
        end
        render 'index', formats: :html, layout: 'mat_views/turbo_frame', locals: { row_meta: @row_meta }
      end

      # GET /:lang/admin/definitions/:id
      #
      # Shows a single definition, including run history.
      #
      # @return [void]
      def show
        authorize_mat_views!(:read, :mat_views_definition, @definition)
        @mv_exists = MatViews::Services::CheckMatviewExists.new(@definition).call.response[:exists]
        @runs = @definition.mat_view_runs.order(created_at: :desc).to_a
        render 'show', formats: :html, layout: 'mat_views/turbo_frame'
      end

      # GET /:lang/admin/definitions/new
      #
      # Renders the new definition form.
      #
      # @return [void]
      def new
        authorize_mat_views!(:create, :mat_views_definition)
        @definition = MatViews::MatViewDefinition.new
        render 'form', formats: :html, layout: 'mat_views/turbo_frame'
      end

      # POST /:lang/admin/definitions
      #
      # Creates a new definition from params.
      #
      # @return [void]
      def create
        authorize_mat_views!(:create, :mat_views_definition)
        @definition = MatViews::MatViewDefinition.new(definition_params)
        if @definition.save
          handle_frame_response(status: 298)
        else
          render 'form', formats: :html, layout: 'mat_views/turbo_frame', status: :unprocessable_content
        end
      end

      # GET /:lang/admin/definitions/:id/edit
      #
      # Renders the edit form for an existing definition.
      #
      # @return [void]
      def edit
        authorize_mat_views!(:update, :mat_views_definition, @definition)
        render 'form', formats: :html, layout: 'mat_views/turbo_frame'
      end

      # PATCH/PUT /:lang/admin/definitions/:id
      #
      # Updates an existing definition.
      #
      # @return [void]
      def update
        authorize_mat_views!(:update, :mat_views_definition, @definition)
        if @definition.update(definition_params)
          handle_frame_response(status: 298)
        else
          render 'form', formats: :html, layout: 'mat_views/turbo_frame', status: :unprocessable_content
        end
      end

      # DELETE /:lang/admin/definitions/:id
      #
      # Destroys the definition. Frame-specific redirect/empty response.
      #
      # @return [void]
      def destroy
        authorize_mat_views!(:destroy, :mat_views_definition, @definition)
        @definition.destroy!
        if @frame_id == 'dash-definitions'
          redirect_to admin_mat_view_definitions_path(frame_id: @frame_id), status: :see_other
        else
          render 'empty', formats: :html, layout: 'mat_views/turbo_frame', status: 298
        end
      end

      # POST /:lang/admin/definitions/:id/create_now
      #
      # Immediately enqueues a background job to create the materialised view.
      #
      # @return [void]
      def create_now
        authorize_mat_views!(:create, :mat_views_definition_view, @definition)

        force = params[:force].to_s.downcase == 'true'
        MatViews::Jobs::Adapter.enqueue(
          MatViews::CreateViewJob,
          queue: MatViews.configuration.job_queue,
          args: [@definition.id, force, row_count_strategy]
        )
        handle_frame_response
      end

      # POST /:lang/admin/definitions/:id/refresh
      #
      # Immediately enqueues a background job to refresh the materialised view.
      #
      # @return [void]
      def refresh
        authorize_mat_views!(:update, :mat_views_definition_view, @definition)
        MatViews::Jobs::Adapter.enqueue(
          MatViews::RefreshViewJob,
          queue: MatViews.configuration.job_queue,
          args: [@definition.id, row_count_strategy]
        )
        handle_frame_response
      end

      # POST /:lang/admin/definitions/:id/delete_now
      #
      # Immediately enqueues a background job to delete the materialised view.
      #
      # @return [void]
      def delete_now
        authorize_mat_views!(:destroy, :mat_views_definition_view, @definition)

        cascade = params[:cascade].to_s.downcase == 'true'
        MatViews::Jobs::Adapter.enqueue(
          MatViews::DeleteViewJob,
          queue: MatViews.configuration.job_queue,
          args: [@definition.id, cascade, row_count_strategy]
        )
        handle_frame_response
      end

      private

      # Returns the configured row count strategy for admin UI operations.
      #
      # @api private
      #
      # @return [Symbol, nil] row count strategy (e.g., :estimated, :exact, :none)
      def row_count_strategy
        MatViews.configuration.admin_ui[:row_count_strategy] || :none
      end

      # Handles redirect/response after a frame-based action.
      #
      # @api private
      #
      # @param status [Symbol,Integer] the HTTP status for redirect
      # @return [void]
      def handle_frame_response(status: :see_other)
        if @frame_id == 'dash-definitions'
          dtsort = params[:dtsort]
          dtfilter = params[:dtfilter]
          dtsearch = params[:dtsearch]
          redirect_to admin_mat_view_definitions_path(frame_id: @frame_id, stream: true, dtsort:, dtfilter:, dtsearch:), status: status
        else
          redirect_to admin_mat_view_definition_path(@definition, frame_id: @frame_id), status: status
        end
      end

      # Loads a definition by `params[:id]`.
      #
      # @api private
      #
      # @return [void]
      def set_definition
        @definition = MatViews::MatViewDefinition.find(params[:id])
      end

      # Normalizes array fields (unique_index_columns, dependencies) from
      # comma-separated strings into arrays.
      #
      # @api private
      #
      # @return [void]
      def normalize_array_fields
        normalize_array_field(:mat_view_definition, :unique_index_columns)
        normalize_array_field(:mat_view_definition, :dependencies)
      end

      # Normalizes a specific array field from a comma-separated string into an array.
      #
      # @api private
      #
      # @param object_key [Symbol] the params object key (e.g., :mat_view_definition)
      # @param array_key [Symbol] the specific array field key (e.g., :unique_index_columns)
      #
      # @return [void]
      def normalize_array_field(object_key, array_key)
        object = params[object_key]

        values = object[array_key]
        return if values.nil?

        object[array_key] = values.split(',').map(&:strip).reject(&:blank?)
      end

      # Strong params for mat view definitions.
      #
      # @api private
      #
      # @return [ActionController::Parameters]
      def definition_params
        params.require(:mat_view_definition).permit(
          :name, :sql, :refresh_strategy, :schedule_cron,
          unique_index_columns: [], dependencies: []
        )
      end

      # Loads data for the index datatable with filtering, searching, sorting, and pagination.
      # sets @data.
      #
      # @api private
      #
      # @return [void]
      def index_dt_load_data
        rel = MatViews::MatViewDefinition
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
          id: 'mv-definitions-table',
          index_url: admin_mat_view_definitions_path(frame_id: @frame_id),
          frame_id: 'mv-definitions-datatable',
          columns: columns,
          dt_humanize_ref: 'MatViews::MatViewDefinition',
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
          name: {
            label_ref: 'name',
            label_type: 'humanize_attr',
            sort: 'name',
            filter: 'name',
            search: 'name'
          },
          refresh_strategy: {
            label_ref: 'refresh_strategy',
            label_type: 'humanize_attr',
            sort: 'refresh_strategy',
            filter: 'refresh_strategy',
            search: 'refresh_strategy'
          },
          schedule_cron: {
            label_ref: 'schedule_cron',
            label_type: 'humanize_attr',
            sort: 'schedule_cron',
            filter: 'schedule_cron',
            search: 'schedule_cron'
          },
          last_run_at: {
            label_ref: 'last_run_at',
            label_type: 'humanize_attr',
            sort: 'last_run_at',
            filter: nil,
            search: 'last_run_at'
          },
          actions: {
            label_ref: 'actions',
            label_type: 'i18n',
            th_style: 'justify-content: end;',
            filter: nil,
            sort: nil,
            search: nil
          }
        }
      end

      # Builds a map of definition names to their existence status in the database.
      # If definitions is nil or empty, returns an empty hash.
      #
      # @api private
      #
      # @param definitions [Array<MatViews::MatViewDefinition>] the definitions to check
      # @return [Hash{String => Boolean}] map of definition names to existence status
      # e.g., { "my_view" => true, "other_view" => false }
      def build_matview_exists_map(definitions)
        return {} if definitions.blank?

        definitions.to_h do |definition|
          exists = MatViews::Services::CheckMatviewExists.new(definition).call.response[:exists]
          [definition.name, exists]
        end
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
        @row_meta = { mv_exists_map: build_matview_exists_map(@data) }
      end
    end
  end
end
