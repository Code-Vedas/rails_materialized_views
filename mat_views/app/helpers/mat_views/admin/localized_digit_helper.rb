# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  module Admin
    # MatViews::Admin::LocalizedDigitHelper
    # -----------------------------------
    # Helper methods for localizing digits in strings and dates.
    # This is used in the admin UI to display numbers according to the current locale.
    #
    # Responsibilities:
    # - Map ASCII digits (0-9) to localized representations based on I18n.t('numbers').
    # - Replace digits in strings or numeric inputs with their localized equivalents.
    # - Localize dates/times with localized digits.
    #
    # Methods:
    # - localized_numbers: returns a hash mapping '0'-'9' to localized strings.
    # - localized_digits: replaces digits in a string or number with localized versions.
    # - l_with_digits: localizes an object (e.g. date/time) and replaces digits.
    module LocalizedDigitHelper
      private

      # Replaces ASCII digits in the input with their localized equivalents.
      #
      # @api private
      #
      # @param str_or_num [String, Numeric] the input string or number
      # @return [String] the input with digits replaced by localized versions
      def localized_digits(str_or_num)
        str_or_num.to_s.gsub(/[0-9]/, localized_numbers)
      end

      # Returns a hash mapping ASCII digits ('0'-'9') to their localized equivalents.
      #
      # @api private
      #
      # @return [Hash{String => String}] mapping of '0'-'9' to localized strings
      def localized_numbers
        map = I18n.t('numbers', default: nil)
        {
          '0' => map[:zero],
          '1' => map[:one],
          '2' => map[:two],
          '3' => map[:three],
          '4' => map[:four],
          '5' => map[:five],
          '6' => map[:six],
          '7' => map[:seven],
          '8' => map[:eight],
          '9' => map[:nine]
        }.compact
      end

      # Localizes an object (e.g. date/time) using I18n.l and replaces digits with localized versions.
      #
      # @api private
      #
      # @param obj [Object] the object to localize
      # @param kwargs [Hash] additional keyword arguments passed to I18n.l
      # @return [String] the localized string with digits replaced
      def l_with_digits(obj, **)
        localized_digits(I18n.l(obj, **))
      end
    end
  end
end
