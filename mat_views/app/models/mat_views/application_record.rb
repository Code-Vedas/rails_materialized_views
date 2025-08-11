# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  # ApplicationRecord is the base class for all models in the MatViews application.
  # It inherits from ActiveRecord::Base and sets the abstract class flag.
  #
  # This class can be extended to define common behavior for all models in the application.
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
