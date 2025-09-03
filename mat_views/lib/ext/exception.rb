# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Extend the Exception class to add a method for serializing error details.
class Exception
  # Serialize the exception into a hash with message, class, and backtrace.
  #
  # @return [Hash] serialized error details
  def serialize_error
    {
      message: message,
      class: self.class.name,
      backtrace: Array(backtrace)
    }
  end
end
