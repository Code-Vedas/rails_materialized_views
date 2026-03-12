# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module Smriti
  module Admin
    #
    # Smriti::Admin::AuthBridge
    # ---------------------------
    # Bridge module that wires the Smriti admin engine to a **host-provided**
    # authentication/authorization layer, while providing safe defaults.
    #
    # ### How it works
    # - Includes {Smriti::Admin::DefaultAuth} first (fallback, no-op/hostable).
    # - Then includes the **host auth module** returned by {.host_auth_module}.
    #   Because Ruby searches the most recently included module first, the host
    #   module cleanly **overrides** any defaults from `DefaultAuth`.
    # - Registers a before_action `authenticate_smriti!`.
    # - Exposes helpers: `smriti_current_user` and its alias {#user}.
    #
    # ### Host integration options (define one of these):
    # 1) A top-level module:
    #    ```ruby
    #    # app/lib/smriti_admin.rb (or any autoloaded path)
    #    module SmritiAdmin
    #      def authenticate_smriti!;  end
    #      def authorize_smriti!(*); end
    #      def smriti_current_user;  end
    #    end
    #    ```
    # 2) A namespaced module:
    #    ```ruby
    #    # app/lib/smriti/admin/host_auth.rb
    #    module Smriti
    #      module Admin
    #        module HostAuth
    #          def authenticate_smriti!;  end
    #          def authorize_smriti!(*); end
    #          def smriti_current_user;  end
    #        end
    #      end
    #    end
    #    ```
    #
    # If neither module is present, a blank `Module.new` is included and the
    # defaults in {Smriti::Admin::DefaultAuth} remain in effect.
    #
    # @see Smriti::Admin::DefaultAuth
    #
    module AuthBridge
      extend ActiveSupport::Concern

      included do
        # Include defaults first, so the host module (included below) can override.
        include Smriti::Admin::DefaultAuth
        include host_auth_module

        before_action :authenticate_smriti!
        helper_method :smriti_current_user, :user
      end

      # Convenience alias for `smriti_current_user` exposed to views.
      #
      # @return [Object, nil] the current user object as defined by host auth
      def user = smriti_current_user

      class_methods do
        # Resolves the host's auth module, if any.
        #
        # Lookup order:
        # 1. `::SmritiAdmin`
        # 2. `::Smriti::Admin::HostAuth`
        # 3. Fallback: a blank Module (no overrides)
        #
        # @return [Module] the module to include for host auth overrides
        def host_auth_module
          if Object.const_defined?('SmritiAdmin')
            ::SmritiAdmin
          elsif Object.const_defined?('Smriti') &&
                Smriti.const_defined?('Admin') &&
                Smriti::Admin.const_defined?('HostAuth')
            ::Smriti::Admin::HostAuth
          else
            Module.new
          end
        end
      end
    end
  end
end
