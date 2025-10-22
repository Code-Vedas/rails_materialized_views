# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# MatViewsPaginate
# ----------------
# Concern that adds a class-level `paginate` scope to models, enabling
# simple pagination based on `page` and `per_page` parameters.
#
# ## Usage
# ```ruby
# MatViews::MatViewDefinition.paginate(total: 100, page: 2, per_page: 20)
# # => Returns records 21-40 of the total 100
# ```
#
# @note Methods are added as **class methods** to the including model.
#
# @!method self.paginate(total:, page:, per_page:)
#   Paginates the relation based on total records, current page, and per-page count.
#   @param total [Integer] Total number of records in the full result set.
#   @param page [Integer] Current page number (1-based).
#   @param per_page [Integer] Number of records per page.
#   @return [ActiveRecord::Relation] Paginated relation.
#
module MatViewsPaginate
  extend ActiveSupport::Concern

  included do
    # Adds a scope for paginating records.
    # Usage: Model.paginate(total: total_count, page: current_page, per_page: per_page_count)
    #
    # Calculates the correct offset and limit based on the provided parameters.
    # Ensures page and per_page are within valid ranges.
    # Defaults per_page to 20 if an invalid value is provided.
    # Returns an ActiveRecord::Relation with the appropriate records.
    #
    # @param total [Integer] Total number of records in the full result set.
    # @param page [Integer] Current page number (1-based).
    # @param per_page [Integer] Number of records per page.
    #
    # @return [ActiveRecord::Relation] Paginated relation.
    scope :paginate, lambda { |total:, page:, per_page:|
      page = page.to_i
      per_page  = per_page.to_i
      per_page  = 20 if per_page <= 0

      total_pages = (total.to_f / per_page).ceil
      page = 1 if page < 1 || (page > total_pages && total_pages.positive?)

      offset((page - 1) * per_page).limit(per_page)
    }
  end
  class_methods do
    # Calculates the total number of pages based on total records and per-page count.
    #
    # @param total [Integer] Total number of records.
    # @param per_page [Integer] Number of records per page.
    # @return [Integer] Total number of pages.
    #
    # @example
    #   total_pages(total: 100, per_page: 20) #=> 5
    def total_pages(total:, per_page:)
      per_page = per_page.to_i
      (total.to_f / per_page).ceil
    end
  end
end
