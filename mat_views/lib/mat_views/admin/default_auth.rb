# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Admin
    # MatViews::Admin::DefaultAuth
    # ----------------------------
    # Development-friendly **fallback** authentication/authorization for the MatViews
    # admin UI. It is included first by {MatViews::Admin::AuthBridge}, and is meant
    # to be overridden by a host-provided module (`MatViewsAdmin` or
    # `MatViews::Admin::HostAuth`).
    #
    # ❗ **Not for production**: this module allows all access and returns a dummy user.
    #
    # @see MatViews::Admin::AuthBridge
    #
    module DefaultAuth
      # Minimal stand-in user object used by the default auth.
      #
      # @!attribute [rw] email
      #   @return [String] the email address of the sample user
      class SampleUser
        attr_accessor :email

        # @param email [String]
        def initialize(email) = @email = email

        # @return [String] the user's email
        def to_s = email
      end

      # Authenticates the current request.
      # Always returns true in the default implementation.
      #
      # @return [Boolean] true
      # rubocop:disable Naming/PredicateMethod
      def authenticate_mat_views! = true
      # rubocop:enable Naming/PredicateMethod

      # Returns the current user object.
      # In the default implementation this is a {SampleUser}.
      #
      # @return [SampleUser]
      def mat_views_current_user = SampleUser.new('sample-user@example.com')

      # Authorizes an action on a record.
      # Always returns true in the default implementation.
      #
      # @param _action [Symbol, String] the attempted action (ignored)
      # @param _type [Symbol, String] the type of resource (ignored)
      # @param _record [Object] the target record or symbol (ignored)
      # @return [Boolean] true
      # rubocop:disable Naming/PredicateMethod
      def authorize_mat_views!(_action, _type, _record = nil) = true
      # rubocop:enable Naming/PredicateMethod
    end
  end
end
