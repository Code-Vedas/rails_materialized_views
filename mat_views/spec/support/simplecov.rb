# frozen_string_literal: true

# ─────────────────────────────────────────────────────────────────────────────
# SimpleCov setup (warn-only by default; strict if STRICT_COVERAGE=1)
# ─────────────────────────────────────────────────────────────────────────────

# Load first thing when running specs
require 'simplecov'

SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter
]

begin
  require 'simplecov-console'
  SimpleCov.formatters << SimpleCov::Formatter::Console
rescue LoadError
  # fallback to default text formatter
end

SimpleCov.start do
  enable_coverage :branch

  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/db/'
  add_filter '/vendor/'

  add_group 'Models', 'app/models'
  add_group 'Jobs', 'app/jobs'
  add_group 'Services', 'lib/mat_views/services'
  add_group 'Lib', 'lib'
end

SOFT_TARGET = 100.0

SimpleCov.at_exit do
  result = SimpleCov.result
  result.format!

  covered = result.covered_percent.round(2)

  if ENV['STRICT_COVERAGE'] == '1'
    if covered < SOFT_TARGET
      warn "SimpleCov: coverage #{covered}% is below required #{SOFT_TARGET}% — failing (STRICT_COVERAGE=1)."
      exit(SimpleCov::ExitCodes::MINIMUM_COVERAGE)
    end
  elsif covered < SOFT_TARGET
    warn "SimpleCov: coverage #{covered}% is below target #{SOFT_TARGET}%. (warn-only; build will not fail)"
  end
end
