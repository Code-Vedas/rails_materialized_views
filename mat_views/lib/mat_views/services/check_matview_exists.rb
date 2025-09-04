# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Services
    # MatViews::Services::CheckMatviewExists
    # --------------------------------------
    # Service object that checks whether the underlying PostgreSQL **materialized view**
    # for a given {MatViews::MatViewDefinition} currently exists.
    #
    # ### Contract
    # - Inherits from {MatViews::Services::BaseService}.
    # - Uses BaseService helpers such as `definition`, `view_exists?`,
    #   `ok`, `raise_err`, and the `request`/`response` accessors.
    # - The public entrypoint is `#call` (defined in BaseService), which will call the
    #   private lifecycle hooks here: {#prepare}, {#assign_request}, and {#_run}.
    #
    # ### Result
    # - On success: status `:ok`, with `response: { exists: true|false }`.
    # - On validation failure (bad view name): raises via {BaseService#raise_err}.
    #
    # @example Check if a materialized view exists
    #   defn = MatViews::MatViewDefinition.find(1)
    #   res  = MatViews::Services::CheckMatviewExists.new(defn).call
    #   if res.success?
    #     puts res.response[:exists] ? "Exists" : "Missing"
    #   else
    #     warn res.error
    #   end
    #
    # @see MatViews::Services::BaseService
    # @see MatViews::MatViewDefinition
    #
    class CheckMatviewExists < BaseService
      private

      # Core execution step (invoked by BaseService#call).
      #
      # @api private
      #
      # Sets {#response} to `{ exists: Boolean }` and marks the service as ok.
      #
      # @return [void]
      def _run
        self.response = { exists: view_exists? }
        ok(:ok)
      end

      # Validation step (invoked by BaseService#call before execution).
      #
      # @api private
      #
      # Empty for this service as no other preparation is needed.
      #
      # @return [void]
      def prepare; end

      # Request initialization (invoked by BaseService#call).
      #
      # @api private
      #
      # Establishes a canonical, immutable snapshot of the input request
      # for logging/inspection purposes. This service does not require inputs,
      # so it assigns an empty Hash.
      #
      # @return [void]
      def assign_request
        self.request = {}
      end
    end
  end
end
