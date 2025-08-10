# frozen_string_literal: true

module MatViews
  # ServiceResponse is a class that encapsulates the result of a service operation.
  # It includes the status of the operation, any payload data, error information,
  # duration of the operation, and additional metadata.
  class ServiceResponse
    attr_reader :status, :payload, :error, :meta

    def initialize(status:, payload: {}, error: nil, meta: {})
      @status = status.to_sym
      @payload = payload
      @error = error
      @meta = meta
    end

    def success?
      !error? && %i[ok created updated noop].include?(status)
    end

    def error?
      !error.nil? || status == :error
    end

    def to_h
      { status:, payload:, error:, meta: }
    end
  end
end
