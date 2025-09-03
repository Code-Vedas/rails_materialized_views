# CHANGELOG

## [0.1.2](https://github.com/code-vedas/rails_materialized_views/tree/v0.1.1) (2025-08-22)

[Full Changelog](https://github.com/code-vedas/rails_materialized_views/compare/v0.1.0...v0.1.2)

## 🧰 Maintenance

- refactor: Unify run tracking into a single `mat_view_runs` table @niteshpurohit (#97)
- chore(deps): Bump actions/checkout from 4 to 5 @[dependabot[bot]](https://github.com/apps/dependabot) (#95)
- refactor: qlty fixes @niteshpurohit (#94)

## ⚙️ CI

- ci: Integrate Qlty coverage reporting @niteshpurohit (#93)

## [0.1.1](https://github.com/code-vedas/rails_materialized_views/compare/v0.1.0...v0.1.1) Skiped

Due to issues with rubygems.org, the 0.1.1 release has been skipped.

## [0.1.0](https://github.com/code-vedas/rails_materialized_views/tree/v0.1.0) (2025-08-18)

[Full Changelog](https://github.com/code-vedas/rails_materialized_views/compare/080a0c5f8f42eb55e971677f0468ed626e2b3b44...v0.1.0)

## 🚀 Features

- feat: Adds rake task to validate MV performance @niteshpurohit (#82)
- feat: Add Rails demo application for mat_views gem @niteshpurohit (#81)
- feat: Add rake tasks to delete materialized views @niteshpurohit (#79)
- feat: Add service and job to delete materialized views @niteshpurohit (#78)
- feat: Add tracking for materialized view deletions @niteshpurohit (#76)
- feat: Add rake tasks for managing materialized views @niteshpurohit (#71)
- feat: Add service and job for refreshing materialized views using swap @niteshpurohit (#70)
- feat: Add service and job for refreshing materialized views concurrently @niteshpurohit (#68)
- feat: Add service and job for refreshing materialized views normally @niteshpurohit (#67)
- feat: Add service and job for creating materialized views @niteshpurohit (#65)
- feat: Adds model to track materialized view creation runs @niteshpurohit (#63)
- feat: Add job adapter for background processing @niteshpurohit (#61)
- feat: Add FactoryBot for test data generation @niteshpurohit (#60)
- feat: Add data models and seeds to dummy app @niteshpurohit (#54)
- feat: Add models for managing materialized views @niteshpurohit (#47)
- feat: Add install generator and configuration @niteshpurohit (#46)
- feat: Initialize mat_views Rails engine @niteshpurohit (#42)

## 📝 Documentation

- docs: Add comprehensive documentation site @niteshpurohit (#91)
- docs: Add release process and enhance README @niteshpurohit (#88)
- docs: Overhaul project documentation @niteshpurohit (#83)

## 🧰 Maintenance

- chore(deps): Update rails requirement from ~> 7.1 to >= 7.1, < 9.0 in /mat_views @[dependabot[bot]](https://github.com/apps/dependabot) (#90)
- chore(deps): Bump rails from 8.0.2 to 8.0.2.1 in /mat_views @[dependabot[bot]](https://github.com/apps/dependabot) (#80)
- chore(deps-dev): Bump rspec-rails from 8.0.1 to 8.0.2 in /mat_views @[dependabot[bot]](https://github.com/apps/dependabot) (#77)
- chore(deps): Bump actions/checkout from 4 to 5 @[dependabot[bot]](https://github.com/apps/dependabot) (#75)
- chore: Add copyright and license headers @niteshpurohit (#69)
- chore(deps): Bump release-drafter/release-drafter from 5 to 6 @[dependabot[bot]](https://github.com/apps/dependabot) (#55)
- chore: Improve handling of Dependabot PRs @niteshpurohit (#56)
- refactor: Introduce enum for refresh strategies @niteshpurohit (#52)
- chore: Apply consistent style and update linting rules @niteshpurohit (#45)

## ⚙️ CI

- ci: Add release workflow and lock Rails version @niteshpurohit (#89)
- ci: Add SimpleCov for test coverage reporting @niteshpurohit (#66)
- ci: Add CI automation with Danger and Release Drafter @niteshpurohit (#44)
