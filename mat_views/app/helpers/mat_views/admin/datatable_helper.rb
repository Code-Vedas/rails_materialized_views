# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Admin
    # MatViews::Admin::DatatableHelper
    # ---------------------------
    # Helper module providing methods to manage datatable functionalities
    # such as sorting, searching, filtering, and pagination.
    #
    # Responsibilities:
    # - Apply sorting based on request parameters.
    # - Apply searching across multiple columns.
    # - Apply filtering based on specified criteria.
    # - Handle pagination with customizable page size.
    # - Generate pagination window for UI display.
    # - Parse custom headers to parameters for datatable requests.
    # - Render Turbo Stream responses for dynamic datatable updates.
    #
    # Methods:
    # - dt_apply_sort: applies sorting to a relation based on parameters.
    # - dt_apply_search: applies search filtering to a relation.
    # - dt_apply_filter: applies column-based filtering to a relation.
    # - dt_apply_pagination: paginates a relation.
    # - pagination_window: generates page numbers for pagination UI.
    # - parse_headers_to_params: parses custom headers into params.
    # - render_dt_turbo_streams: renders Turbo Stream responses for datatables.
    # - param_dtfilter: accessor for dtfilter param.
    # - param_dtsearch: accessor for dtsearch param.
    # - param_dtsort: accessor for dtsort param.
    module DatatableHelper
      private

      # Applies sorting to the given ActiveRecord relation based on the provided columns and request parameters.
      #
      # @api private
      #
      # @param rel [ActiveRecord::Relation] the relation to sort
      # @param columns [Hash] a hash defining the columns and their sort attributes
      #
      # @return [ActiveRecord::Relation] the sorted relation
      def dt_apply_sort(rel, columns)
        return rel unless param_dtsort.present?

        param_dtsort.split(',').each do |clause|
          col, dir = clause.split(':')
          dir = dir&.downcase == 'desc' ? :desc : :asc
          col_def = columns[col.to_sym]
          col_def_sort = col_def[:sort] if col_def
          rel = rel.send("ordered_by_#{col_def_sort}", dir) if col_def_sort
        end
        rel
      end

      # Applies search filtering to the given ActiveRecord relation based on the provided columns and request parameters.
      #
      # @api private
      #
      # @param rel [ActiveRecord::Relation] the relation to search
      # @param columns [Hash] a hash defining the columns and their search attributes
      #
      # @return [ActiveRecord::Relation] the filtered relation
      def dt_apply_search(rel, columns)
        return rel unless param_dtsearch.present?

        scopes = columns.values.filter_map do |col_def|
          col_def_search = col_def[:search]
          rel.send("search_by_#{col_def_search}", param_dtsearch) if col_def_search
        end

        rel = scopes.reduce { |acc, scope| acc.or(scope) } if scopes.any?

        rel
      end

      # Applies column-based filtering to the given ActiveRecord relation based on the provided columns and request parameters.
      #
      # @api private
      #
      # @param rel [ActiveRecord::Relation] the relation to filter
      # @param columns [Hash] a hash defining the columns and their filter attributes
      #
      # @return [ActiveRecord::Relation] the filtered relation
      def dt_apply_filter(rel, columns)
        return rel unless param_dtfilter.present?

        param_dtfilter.split(',').each do |clause|
          col, val = clause.split(':')
          col_def = columns[col.to_sym]
          col_def_f = col_def[:filter] if col_def
          rel = rel.send("filtered_by_#{col_def_f}", val) if col_def_f && val.present? && rel.respond_to?("filtered_by_#{col_def_f}")
        end
        rel
      end

      # Applies pagination to the given ActiveRecord relation based on request parameters.
      #
      # @api private
      #
      # @param rel [ActiveRecord::Relation] the relation to paginate
      # @param default_per_page [Integer] the default number of items per page
      #
      # @return [ActiveRecord::Relation] the paginated relation
      def dt_apply_pagination(rel, default_per_page)
        @dt_page = (params[:dtpage] || 1).to_i
        @dt_per_page = (params[:dtperpage] || default_per_page).to_i
        total = rel.count
        @dt_total_pages = rel.total_pages(total: total, per_page: @dt_per_page)
        rel.paginate(total: total, page: @dt_page, per_page: @dt_per_page)
      end

      # Returns an array of page numbers and :gap symbols for pagination display
      #
      # @api private
      #
      # Example:
      # pagination_window(current_page: 6, total_pages: 20)
      # => [1, :gap, 4, 5, 6, 7, 8, :gap, 20]
      #
      # Use :gap to render "..." in your view.
      #
      # @param current_page [Integer] the current page number
      # @param total_pages [Integer] the total number of pages
      # @param window [Integer] the number of pages to show on each side of the current page
      #
      # @return [Array<Integer, Symbol>] array of page numbers and :gap symbols
      def pagination_window(current_page:, total_pages:, window: 2)
        return [] if total_pages < 1

        pages = []
        left = [1, current_page - window].max
        right = [total_pages, current_page + window].min

        pages << 1 unless left == 1
        pages << :gap if left > 2

        (left..right).each { |page| pages << page }

        pages << :gap if right < total_pages - 1
        pages << total_pages unless right == total_pages

        pages
      end

      # Parses custom headers into params for datatable requests.
      #
      # @api private
      #
      # This allows clients to send datatable parameters via headers instead of query parameters.
      # In this application, this is used to append headers when making Turbo Frame requests.
      #
      # Headers parsed:
      # - X-Dtsearch -> params[:dtsearch]
      # - X-Dtsort -> params[:dtsort]
      # - X-Dtfilter -> params[:dtfilter]
      # - X-DtPage -> params[:dtpage]
      # - X-DtPerPage -> params[:dtperpage]
      #
      # @return [void]
      def parse_headers_to_params
        parse_header_to_params(:dtsearch, 'X-Dtsearch')
        parse_header_to_params(:dtsort, 'X-Dtsort')
        parse_header_to_params(:dtfilter, 'X-Dtfilter')
        parse_header_to_params(:dtpage, 'X-DtPage')
        parse_header_to_params(:dtperpage, 'X-DtPerPage')
      end

      # Helper method to parse a single header into a parameter if the parameter is not already set.
      #
      # @api private
      #
      # @param param_key [Symbol] the parameter key to set
      # @param header_key [String] the header key to read from
      #
      # @return [void]
      def parse_header_to_params(param_key, header_key)
        return unless request.headers[header_key].present?
        return if params[param_key].present?

        values = request.headers[header_key].split(',').map(&:strip).reject(&:empty?)
        params[param_key] = values.join(',')
      end

      # Renders Turbo Stream responses for datatable updates.
      #
      # @api private
      #
      # This method is used to dynamically update the datatable rows, pagination controls,
      # and filters via Turbo Streams when the datatable requests new data.
      #
      # @dt_config must be set before calling this method.
      #
      # @return [void]
      def render_dt_turbo_streams
        dt_config_id = @dt_config[:id]
        render turbo_stream: [
          turbo_stream.replace(
            "datatable-body-#{dt_config_id}",
            partial: 'mat_views/admin/ui/datatable_tbody',
            locals: { row_meta: @row_meta }
          ),
          turbo_stream.replace(
            "datatable-tfoot-#{dt_config_id}",
            partial: 'mat_views/admin/ui/datatable_tfoot',
            locals: { dt_config: @dt_config, data: @data }
          ),
          if index_dt_config[:filter_enabled]
            turbo_stream.replace(
              "datatable-filters-#{dt_config_id}",
              partial: 'mat_views/admin/ui/datatable_filters',
              locals: { dt_config: @dt_config, dtfilter: params[:dtfilter] || '' }
            )
          end
        ].compact
      end

      # Accessor methods for datatable filter parameter
      #
      # @api private
      #
      # @return [String, nil] the dtfilter parameter from params
      def param_dtfilter
        params[:dtfilter]
      end

      # Accessor methods for datatable search parameter
      #
      # @api private
      #
      # @return [String, nil] the dtsearch parameter from params
      def param_dtsearch
        params[:dtsearch]
      end

      # Accessor methods for datatable sort parameter
      #
      # @api private
      #
      # @return [String, nil] the dtsort parameter from params
      def param_dtsort
        params[:dtsort]
      end
    end
  end
end
