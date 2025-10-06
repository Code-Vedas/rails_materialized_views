# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the mat_views engine.
module MatViews
  ##
  # Base model class for all ActiveRecord models in the mat_views engine.
  #
  # Inherits from {ActiveRecord::Base} and marks itself as an abstract class.
  # Other engine models should subclass this rather than inheriting directly
  # from {ActiveRecord::Base}, so that shared behavior or configuration can be
  # applied in one place.
  #
  # @abstract
  #
  # @example Define a new model under mat_views
  #   class MatViews::MatViewDefinition < MatViews::ApplicationRecord
  #     self.table_name = "mat_view_definitions"
  #   end
  #
  class ApplicationRecord < ActiveRecord::Base
    ##
    # Marks this record class as abstract, so it won’t be persisted to a table.
    #
    # @return [void]
    #
    self.abstract_class = true

    # Include shared concerns for i18n, queries, and pagination.
    include MatViewsI18n
    include MatViewsPaginate
    include MatViewsQueryHelper
  end
end
