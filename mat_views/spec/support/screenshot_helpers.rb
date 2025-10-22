# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Helpers for taking screenshots on test failures.
module ScreenshotHelpers
  def save_failure_screenshot(example)
    return unless example.exception

    dir = Rails.root.join('tmp', 'screenshots')
    FileUtils.mkdir_p(dir)

    stamp = Time.now.strftime('%Y%m%d-%H%M%S')
    name  = example.metadata[:full_description][0..60].parameterize
    path  = dir.join("#{name}-#{stamp}.png")

    page.save_screenshot(path.to_s) # rubocop:disable Lint/Debugger
    RSpec.configuration.reporter.message("Saved screenshot: #{path}")
  end
end
