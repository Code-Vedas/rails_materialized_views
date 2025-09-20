# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require_relative 'lib/mat_views/version'

Gem::Specification.new do |spec|
  spec.name        = 'mat_views'
  spec.version     = MatViews::VERSION
  spec.authors     = ['Nitesh Purohit']
  spec.email       = ['nitesh.purohit.it@gmail.com']
  spec.summary       = 'Manage and refresh PostgreSQL materialised views in Rails'
  spec.description   = 'A mountable Rails engine to track, define, refresh, and monitor Postgres materialised views.'
  spec.homepage      = 'https://github.com/Code-Vedas/rails_materialized_views'
  spec.license       = 'MIT'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/Code-Vedas/rails_materialized_views/issues'
  spec.metadata['changelog_uri'] = 'https://github.com/Code-Vedas/rails_materialized_views/blob/main/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://mat-views.codevedas.com'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/Code-Vedas/rails_materialized_views.git'
  spec.metadata['funding_uri'] = 'https://github.com/sponsors/Code-Vedas'
  spec.metadata['support_uri'] = 'https://mat-views.codevedas.com/support'
  spec.metadata['rubygems_uri'] = 'https://rubygems.org/gems/mat_views'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'rails', '>= 7.1', '< 9.0'
  spec.add_dependency 'rails-i18n', '>= 7.0'
  spec.required_ruby_version = '>= 3.2'
end
