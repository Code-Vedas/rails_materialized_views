# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  ##
  # Encapsulates the result of a service operation within MatViews.
  #
  # Provides a consistent contract for all services by standardizing:
  # - `status`: Symbol representing outcome (`:ok`, `:created`, `:updated`,
  #   `:skipped`, `:deleted`, `:error`)
  # - `request`: Request detailed that service was invoked with
  # - `response`: Response detailed that service returned, nil with :error status
  # - `error`: Exception or error message, with :error status
  #    - `message`: String description of the error
  #    - `class`: Exception class name
  #    - `backtrace`: Array of strings
  #
  # @example Successful response
  #   MatViews::ServiceResponse.new(
  #     status: :updated,
  #     response: { ... }
  #   )
  #
  # @example Error response
  #   MatViews::ServiceResponse.new(
  #     status: :error,
  #     error: StandardError.new("Something went wrong")
  #   )
  #
  class ServiceResponse
    attr_reader :status, :request, :error, :response

    # acceptable status values
    ACCEPTABLE_STATES = %i[ok created updated skipped deleted error].freeze

    # statuses indicating success
    OK_STATES = %i[ok created updated skipped deleted].freeze

    # statuses indicating error
    ERROR_STATES = %i[error].freeze

    # @param status [Symbol] the outcome status
    # @param request [Hash] request details
    # @param response [Hash] response details
    # @param error [Exception, String, nil] error details if applicable
    def initialize(status:, request: {}, response: {}, error: nil)
      raise ArgumentError, 'status is required' unless ACCEPTABLE_STATES.include?(status&.to_sym)
      raise ArgumentError, 'error must be Exception object' if error && !error.is_a?(Exception)

      @status = status.to_sym
      @request = request
      @response = response
      @error = error&.mv_serialize_error
    end

    # @return [Boolean] whether the response represents a success
    def success?
      OK_STATES.include?(status)
    end

    # @return [Boolean] whether the response represents an error
    def error?
      ERROR_STATES.include?(status)
    end

    # @return [Hash] hash representation of the response
    def to_h
      { status:, request:, response:, error: }.compact
    end
  end
end
