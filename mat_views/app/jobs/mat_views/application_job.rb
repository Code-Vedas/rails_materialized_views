# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

##
# Top-level namespace for the mat_views engine.
#
# All classes, modules, and services for materialized view management
# are defined under this namespace.
#
# @example Accessing a job
#   MatViews::ApplicationJob
#
module MatViews
  ##
  # Base class for all background jobs in the mat_views engine.
  #
  # Inherits from {ActiveJob::Base} and provides a common superclass
  # for engine jobs such as {MatViews::CreateViewJob} and {MatViews::RefreshViewJob}.
  #
  # @abstract
  #
  # @see MatViews::CreateViewJob
  # @see MatViews::RefreshViewJob
  # @see MatViews::DeleteViewJob
  #
  # @example Defining a custom job
  #   class MyCustomJob < MatViews::ApplicationJob
  #     def perform(definition_id)
  #       # custom logic here
  #     end
  #   end
  #
  class ApplicationJob < ActiveJob::Base
  end
end
