require_relative "lib/mat_views/version"

Gem::Specification.new do |spec|
  spec.name        = "mat_views"
  spec.version     = MatViews::VERSION
  spec.authors     = [ "Nitesh Purohit" ]
  spec.email       = [ "nitesh.purohit.it@gmail.com" ]
  spec.summary       = "Manage and refresh PostgreSQL materialized views in Rails"
  spec.description   = "A mountable Rails engine to track, define, refresh, and monitor Postgres materialized views."
  spec.homepage      = "https://github.com/Code-Vedas/rails_materialized_views"
  spec.license       = "MIT"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Code-Vedas/rails_materialized_views"
  spec.metadata["changelog_uri"] = "https://github.com/Code-Vedas/rails_materialized_views/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.0.2"
  spec.add_development_dependency "rspec-rails"
end
