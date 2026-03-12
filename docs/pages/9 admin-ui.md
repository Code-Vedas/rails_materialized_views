---
title: Admin UI
layout: page
nav_order: 9
permalink: /admin-ui
---

# Admin UI

The Admin UI provides a user-friendly interface to manage and monitor your materialized views. It allows you to create, refresh, and delete materialized views, as well as view their status and performance metrics.

# Configure Admin UI Authentication

To secure the Admin UI, you can configure authentication using any authentication system of your choice.

The Admin UI accepts a module similar to `Smriti::Admin::DefaultAuth` just create a module named `SmritiAdmin` or `Smriti::Admin::HostAuth` in your application and implmenent similar methods as in `Smriti::Admin::DefaultAuth`. `Smriti::Admin::AuthBridge` will include your module if it exists, otherwise it will fall back to `Smriti::Admin::DefaultAuth`.

_important_ `Smriti::Admin::AuthBridge` is permisve by default and allows all access. You can override the methods to implement your own authentication and authorization logic.

## authorize_smriti! method

The `authorize_smriti!` method is called to check if the current user is authorized to perform a specific action on a resource. You can implement your own logic to check if the user has the required permissions.

Following are the actions and resources that you can authorize:

| Action     | Resource                     | Description                                           | Object/Record                        |
| ---------- | ---------------------------- | ----------------------------------------------------- | ------------------------------------ |
| `:view`    | `:smriti_dashboard`       | View the dashboard, preferences page                  | nil                                  |
| `:read`    | `:smriti_definitions`     | View the list of materialized views                   | nil                                  |
| `:create`  | `:smriti_definition`      | Create a new materialized view                        | nil                                  |
| `:update`  | `:smriti_definition`      | Update an existing materialized view                  | Smriti::MatViewDefinition instance |
| `:destroy` | `:smriti_definition`      | Delete a materialized view                            | Smriti::MatViewDefinition instance |
| `:create`  | `:smriti_definition_view` | Create actual database view for a materialized view   | Smriti::MatViewDefinition instance |
| `:update`  | `:smriti_definition_view` | Refresh the materialized view                         | Smriti::MatViewDefinition instance |
| `:destroy` | `:smriti_definition_view` | Drop the actual database view for a materialized view | Smriti::MatViewDefinition instance |
| `:read`    | `:smriti_runs`            | View the list of materialized view runs               | nil                                  |
| `:read`    | `:smriti_run`             | View details of a materialized view run               | Smriti::MatViewRun instance        |

## `Smriti::Admin::DefaultAuth`

```ruby
# Smriti::Admin::DefaultAuth
# ----------------------------
# Development-friendly **fallback** authentication/authorization for the Smriti
# admin UI. It is included first by {Smriti::Admin::AuthBridge}, and is meant
# to be overridden by a host-provided module (`SmritiAdmin` or
# `Smriti::Admin::HostAuth`).
#
# ❗ **Not for production**: this module allows all access and returns a dummy user.
#
# @see Smriti::Admin::AuthBridge
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
  def authenticate_smriti! = true
  # rubocop:enable Naming/PredicateMethod

  # Returns the current user object.
  # In the default implementation this is a {SampleUser}.
  #
  # @return [SampleUser]
  def smriti_current_user = SampleUser.new('sample-user@example.com')

  # Authorizes an action on a record.
  # Always returns true in the default implementation.
  #
  # @param _action [Symbol, String] the attempted action (ignored)
  # @param _type [Symbol, String] the type of resource (ignored)
  # @param _record [Object] the target record or symbol (ignored)
  # @return [Boolean] true
  # rubocop:disable Naming/PredicateMethod
  def authorize_smriti!(_action, _type, _record = nil) = true
  # rubocop:enable Naming/PredicateMethod
end
```

# Links

Admin UI for preview is organized under locale and light/dark mode. You can access it via the following links:
