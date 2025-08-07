# frozen_string_literal: true

module MatViews
  # ApplicationRecord is the base class for all models in the MatViews application.
  # It inherits from ActiveRecord::Base and sets the abstract class flag.
  #
  # This class can be extended to define common behavior for all models in the application.
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
