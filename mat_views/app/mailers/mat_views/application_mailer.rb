# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

module MatViews
  # ApplicationMailer is the base class for all mailers in the MatViews application.
  # It sets the default 'from' address and specifies the layout for emails.
  #
  # This class can be extended to define custom mailer methods as needed.
  class ApplicationMailer < ActionMailer::Base
    default from: 'from@example.com'
    layout 'mailer'
  end
end
