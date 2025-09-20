# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

#
# MatViewsI18n
# ------------
# Concern that adds convenient **class-level** helpers for model I18n:
# - Humanized attribute names
# - Humanized enum values
# - Select-friendly enum option arrays
# - Placeholders and hints for forms
#
# These helpers rely on Rails’ standard i18n model keys using the model’s
# `model_name.i18n_key` (e.g. `MatViews::MatViewDefinition` → `mat_views/mat_view_definition`).
#
# ## Expected i18n structure (examples)
#
# ```yml
# en-US:
#   activerecord:
#     attributes:
#       mat_views/mat_view_definition:
#         name: "View name"
#         sql: "SQL"
#     enums:
#       mat_views/mat_view_definition:
#         refresh_strategy:
#           regular: "Regular"
#           concurrent: "Concurrent"
#           swap: "Swap"
#     placeholders:
#       mat_views/mat_view_definition:
#         name: "e.g. monthly_sales_mv"
#     hints:
#       mat_views/mat_view_definition:
#         sql: "Use a SELECT statement; no trailing semicolon."
# ```
#
# ## Usage
# ```ruby
# MatViews::MatViewDefinition.human_name(:name)                # => "View name"
# MatViews::MatViewDefinition.human_enum_name(:refresh_strategy, :regular)  # => "Regular"
# MatViews::MatViewDefinition.human_enum_options(:refresh_strategy)
# # => [["Regular","regular"], ["Concurrent","concurrent"], ["Swap","swap"]]
# MatViews::MatViewDefinition.placeholder_for(:name)           # => "e.g. monthly_sales_mv"
# MatViews::MatViewDefinition.hint_for(:sql)                   # => "Use a SELECT statement..."
# ```
#
# @note Methods are added as **class methods** to the including model.
#
# @!method self.human_name(attribute)
#   Humanized (translated) attribute label for this model.
#   Falls back to `attribute.to_s.humanize` when missing.
#   @param attribute [Symbol, String]
#   @return [String]
#
# @!method self.human_enum_name(enum_name, enum_value)
#   Humanized (translated) enum value label.
#   Falls back to `enum_value.to_s.humanize` when missing.
#   @param enum_name [Symbol, String] the enum definition name
#   @param enum_value [Symbol, String, Integer] the value/key of the enum
#   @return [String]
#
# @!method self.human_enum_options(enum_name)
#   Options array suitable for Rails `options_for_select`.
#   @param enum_name [Symbol, String]
#   @return [Array<Array(String, String)>] each item is `[label, value]`
#
# @!method self.placeholder_for(attribute)
#   Form placeholder for the given attribute.
#   Returns empty string if not defined.
#   @param attribute [Symbol, String]
#   @return [String]
#
# @!method self.hint_for(attribute)
#   Form hint/help text for the given attribute.
#   Returns empty string if not defined.
#   @param attribute [Symbol, String]
#   @return [String]
#
module MatViewsI18n
  extend ActiveSupport::Concern

  class_methods do
    # @return [String]
    def human_name(attribute)
      I18n.t(
        "activerecord.attributes.#{model_name.i18n_key}.#{attribute}",
        default: attribute.to_s.humanize
      )
    end

    # human_enum_name(:refresh_strategy, :regular) → "Regular"
    #
    # @param enum_name [Symbol, String]
    # @param enum_value [Symbol, String, Integer]
    # @return [String]
    def human_enum_name(enum_name, enum_value)
      key = enum_value.to_s
      I18n.t(
        "activerecord.enums.#{model_name.i18n_key}.#{enum_name}.#{key}",
        default: key.humanize
      )
    end

    # human_enum_options(:refresh_strategy)
    # → [["Regular","regular"], ["Concurrent","concurrent"], ["Swap","swap"]]
    #
    # @param enum_name [Symbol, String]
    # @return [Array<Array(String, String)>]
    def human_enum_options(enum_name)
      public_send(enum_name.to_s.pluralize).keys.map do |val|
        [human_enum_name(enum_name, val), val]
      end
    end

    # @param attribute [Symbol, String]
    # @return [String]
    def placeholder_for(attribute)
      I18n.t(
        "activerecord.placeholders.#{model_name.i18n_key}.#{attribute}",
        default: ''
      )
    end

    # @param attribute [Symbol, String]
    # @return [String]
    def hint_for(attribute)
      I18n.t(
        "activerecord.hints.#{model_name.i18n_key}.#{attribute}",
        default: ''
      )
    end
  end
end
