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
      before_action :set_definition, only: %i[show edit update destroy create_now refresh delete_now]
      before_action :normalize_array_fields, only: %i[create update]
      before_action :ensure_frame

      # GET /:lang/admin/definitions
      #
      # Lists all definitions with existence checks against the database.
      #
      # @return [void]
      def index
        # sleep 20
        authorize_mat_views!(:read, MatViews::MatViewDefinition)
        @definitions = MatViews::MatViewDefinition.order(:name).to_a
        @mv_exists_map = @definitions.index_with do |defn|
          MatViews::Services::CheckMatviewExists.new(defn).call.response[:exists]
        end
        render 'index', formats: :html, layout: 'mat_views/turbo_frame'
      end

      # GET /:lang/admin/definitions/:id
      #
      # Shows a single definition, including run history.
      #
      # @return [void]
      def show
        authorize_mat_views!(:read, @definition)
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
        authorize_mat_views!(:create, MatViews::MatViewDefinition)
        @definition = MatViews::MatViewDefinition.new
        render 'form', formats: :html, layout: 'mat_views/turbo_frame'
      end

      # POST /:lang/admin/definitions
      #
      # Creates a new definition from params.
      #
      # @return [void]
      def create
        authorize_mat_views!(:create, MatViews::MatViewDefinition)
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
        authorize_mat_views!(:update, @definition)
        render 'form', formats: :html, layout: 'mat_views/turbo_frame'
      end

      # PATCH/PUT /:lang/admin/definitions/:id
      #
      # Updates an existing definition.
      #
      # @return [void]
      def update
        authorize_mat_views!(:update, @definition)
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
        authorize_mat_views!(:destroy, @definition)
        @definition.destroy!
        if @frame_id == 'dash-definitions'
          redirect_to admin_mat_view_definitions_path(frame_id: @frame_id, frame_action: @frame_action), status: :see_other
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
        force = params[:force].to_s.downcase == 'true'
        authorize_mat_views!(:create_view, @definition)
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
        authorize_mat_views!(:refresh, @definition)
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
        authorize_mat_views!(:delete_view, @definition)

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
          redirect_to admin_mat_view_definitions_path(frame_id: @frame_id, frame_action: @frame_action), status: :see_other
        else
          redirect_to admin_mat_view_definition_path(@definition, frame_id: @frame_id, frame_action: @frame_action), status: status
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
    end
  end
end
