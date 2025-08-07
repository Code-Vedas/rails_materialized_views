# frozen_string_literal: true

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
