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
  # - `status`: Symbol representing outcome (`:ok`, `:created`, `:updated`, `:noop`,
  #   `:skipped`, `:deleted`, `:error`)
  # - `payload`: Arbitrary structured data returned by the service
  # - `error`: Exception object or message if an error occurred
  # - `meta`: Additional metadata such as SQL statements, timing, or strategies
  #
  # @example Successful response
  #   MatViews::ServiceResponse.new(
  #     status: :updated,
  #     payload: { view: "public.users_mv" }
  #   )
  #
  # @example Error response
  #   MatViews::ServiceResponse.new(
  #     status: :error,
  #     error: StandardError.new("Something went wrong")
  #   )
  #
  class ServiceResponse
    attr_reader :status, :payload, :error, :meta

    # @param status [Symbol] the outcome status
    # @param payload [Hash] optional data payload
    # @param error [Exception, String, nil] error details if applicable
    # @param meta [Hash] additional metadata
    def initialize(status:, payload: {}, error: nil, meta: {})
      @status = status.to_sym
      @payload = payload
      @error = error
      @meta = meta
    end

    # @return [Boolean] whether the response represents a success
    def success?
      !error? && %i[ok created updated noop skipped deleted].include?(status)
    end

    # @return [Boolean] whether the response represents an error
    def error?
      !error.nil? || status == :error
    end

    # @return [Hash] hash representation of the response
    def to_h
      { status:, payload:, error:, meta: }
    end
  end
end
