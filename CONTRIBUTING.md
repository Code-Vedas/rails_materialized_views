# Contribute to Code Vedas Template Repository

Thank you for expressing your interest in contributing to Code Vedas Template Repository. Your contributions are highly valued, and we appreciate your commitment to enhancing this project. Before initiating any contribution, we kindly request you to carefully review this document.

Feel free to contribute through various avenues such as suggestions, comments, bug reports, or pull requests. To do so, please open an issue or a pull request directly in the repository.

## Community Engagement

There are several ways to become an active part of our community:

1. [Create an issue](https://github.com/Code-Vedas/rails_materialized_views/issues/new/choose) in the repository.
2. Join our mailing list by sending an email to [Join mailing list](mailto:mailing-list@codevedas.com).
3. Participate in our Slack channel by sending an email to [Join slack](mailto:join-slack@codevedas.com).
4. Apply for project membership by sending an email to [Join project](mailto:join-project@codevedas.com). Following an initial screening, an invitation will be extended to you. This membership allows you to create issues, pull requests, and more, directly in the repository without the need to fork it.
5. If you wish to make a financial contribution, please follow GitHub's instructions for donating to the project.

## Code and Documentation

We encourage contributions to both the codebase and documentation.

This project comprises various modules/components, each housed in its dedicated folder/repository. For detailed information, please refer to the README.md file in each respective folder/repository.

The table below provides an overview of all possible modules/components:

| Module/Component | Description                           | Related Language/Framework |
| ---------------- | ------------------------------------- | -------------------------- |
| mat_views        | Rails Materialized Views Engine       | Ruby on Rails              |
| mat_views_demo   | Demo Application for mat_views Engine | Ruby on Rails              |

## Improve Documentation

Contributions to the documentation, including this file, are highly welcomed.

Two ways to contribute to the documentation:

1. Create an issue in the repository with the suggested changes using the appropriate template.
2. Submit a pull request in the repository with the suggested changes, adhering to the specified template.

Both approaches are applicable to this file as well, following the outlined code of conduct.

## Improve Code

Your contributions to the codebase are appreciated. Refer to the README.md file in each folder/repository for detailed information.

Two ways to contribute to the code:

1. Open an issue in the repository with the suggested changes, using the appropriate template.
2. Submit a pull request in the repository with the suggested changes, following the specified template.

### Pull Request

Before creating a pull request, ensure the following:

1. Download and install the code on your local machine.
2. Set up the development environment and verify that it is functioning as expected.
3. Create a branch for your changes, ensuring they work as intended. The branch name should follow the format `feature/<feature-name>`, `bugfix/<bug-name>`, `hotfix/<hotfix-name>`, etc.
4. Run applicable test suites, confirming that all tests pass.
5. Ensure the code adheres to coding standards and best practices.
6. Provide thorough documentation for the changes made.
7. When creating a PR, select the correct template and complete all details. If the template is unavailable, create an issue in the repository for template addition. Failure to complete the template may result in the PR being closed without action.

### Issue

Before creating an issue, perform the following:

1. Invest time in finding a solution to the problem (if applicable).
2. When creating an issue, select the correct template and complete all details. If the template is absent, create an issue in the repository to request its addition. Failure to complete the template may lead to the issue being closed without action.

Both approaches are suitable for various changes, including bug fixes and new features, while adhering to the code of conduct.

### Using factories

We use `factory_bot_rails` for concise test data:

- Factories live in `spec/factories/`.
- Engine models:
  - `create(:mat_view_definition, name: "public.mv_users", sql: "SELECT ...", refresh_strategy: :regular)`
  - `create(:mat_view_run, mat_view_definition: defn, status: :running, operation: :refresh)`

Seed data for dummy app tables (`users`, `accounts`, `events`, `sessions`) is provided via `mat_views/spec/dummy/db/seeds.rb` file. Run `rails db:seed` to populate the database with this data when you are in `mat_views` directory.

### Testing job adapters

Our engine supports multiple background processors via `MatViews.config.job_adapter`:

- `:active_job` (default)
- `:sidekiq`
- `:resque`

The smoke specs verify that `MatViews::Jobs::Adapter.enqueue` dispatches correctly to each adapter.

#### How to switch adapters when running specs

Specs set the adapter explicitly, but you can override locally in a console:

```ruby
MatViews.configure do |c|
  c.job_adapter = :sidekiq   # or :active_job, :resque
  c.job_queue   = 'mat_views'
end
```

#### ActiveJob tests

We use the ActiveJob test adapter. RSpec tag `:active_job` sets:

```ruby
ActiveJob::Base.queue_adapter = :test
```

#### Sidekiq + Resque

Specs expect the gems to be present and assert calls to:

- `Sidekiq::Client.push(...)`
- `Resque.enqueue_to(queue, klass, *args)`

## Enhance Security

Contributions to the security aspects of the project are highly appreciated. To report a security vulnerability, please follow the instructions outlined in the [SECURITY.md](SECURITY.md) file.

## CLAs

We require all contributors to sign a Contributor License Agreement (CLA) before accepting any contributions. This ensures that we can legally incorporate your contributions into the project.

You will be prompted to sign a CLA when you open your first pull request. Please follow the instructions provided in the prompt to complete the process. Without a signed CLA, we will not be able to accept your contributions.

There is no expiration date for CLAs. Once signed, your CLA will remain valid for all future contributions to this project.

## Documentation

This project uses [Jekyll](https://jekyllrb.com/) to generate documentation pages from markdown files located in the `docs/pages/` directory. The documentation is built and published automatically using GitHub Pages.

### General instructions to run Jekyll locally

1. Ensure you have Ruby and Bundler installed on your machine.
2. Navigate to the `docs/` directory in your terminal.
3. Install the required gems by running:

   ```bash
   bundle install
   ```

4. Start the Jekyll server with:

   ```bash
   bundle exec jekyll serve
   ```

5. Open your web browser and go to `http://localhost:4000` to view the documentation.

### Updating docs

When changes are made to the codebase, please ensure that the documentation is updated accordingly. This includes updating any relevant markdown files in the `docs/pages/` directory or adding new files for new features or changes.

### App Screenshots

The documentation includes screenshots of the Admin UI in various locales and themes. These screenshots are stored in the `docs/assets/images/app-screenshots/` directory.

When there are user-visible changes in the Admin UI, please update the screenshots accordingly. Screenshots can be generated by running the end-to-end tests with the command:

```bash
cd mat_views
bin/rspec-e2e
```

This command will save the screenshots to the `spec/dummy/tmp/app-screenshots/<locale>/<theme>/` directory. Each set must contain 7 images:

- definitions_list.png
- definitions_view.png
- definitions_new.png
- definitions_edit.png
- runs_list.png
- runs_view.png
- preferences.png
  Copy the new screenshots to the appropriate folder in `docs/assets/images/app-screenshots/` and update the relevant markdown files in `docs/pages/` to reflect the new screenshots, or create new files for new locales/themes.

## Release Process

To release a new version of the `mat_views` engine, follow these steps.

Pick the version number from draft release notes on the
[releases page](https://github.com/Code-Vedas/rails_materialized_views/releases).

1. **Create a release branch**  
   Branch off `main` to a new branch named `release/<version>`.

   ```bash
      git checkout main
      git pull
      git checkout -b release/<version>
   ```

2. **Update the version**
   Update the version in `mat_views.gemspec` to `<version>`.

3. **Update CHANGELOG**
   Copy the draft release notes from the
   [releases page](https://github.com/Code-Vedas/rails_materialized_views/releases)
   and paste them into `CHANGELOG.md` under a new `## <version> - YYYY-MM-DD` section.

4. **Docs sweep**
   Update all relevant docs to reflect this version (version number, features, fixes, usage):
   - Root `README.md` and `mat_views/README.md`
   - `mat_views_demo/README.md` (new commands/configs if any)
   - `CONTRIBUTING.md` (if contributor process changed)
5. **App Screenshots**
   If there are any user-visible changes, update the app screenshots in `docs/assets/images/app-screenshots/`:
   - When running bin/rspec-e2e, screenshots are saved to `spec/dummy/tmp/app-screenshots/<locale>/<theme>/`
   - Each set must contain 7 images:
     - definitions_list.png
     - definitions_view.png
     - definitions_new.png
     - definitions_edit.png
     - runs_list.png
     - runs_view.png
     - preferences.png
   - Copy them to the appropriate folder in `docs/assets/images/app-screenshots/`
   - Update the relevant markdown files in `docs/pages/` to reflect the new screenshots, or create new files for new locales/themes.

6. **Verify release notes**
   Ensure the notes accurately reflect all user-visible changes in this version.

7. **Pre-flight checks (must pass)**
   Run lint and tests locally (CI will run them again):

   ```bash
   bundle exec rubocop
   bundle exec rspec
   ```

   Fix any failures before proceeding.

8. **Commit and push the release branch**

   ```bash
   git add -A
   git commit -m "release: prepare v<version>"
   git push -u origin release/<version>
   ```

9. **Open a PR to `main`**
   Create a pull request to merge `release/<version>` into `main`.

10. **Label the PR**
    Tag the PR with `release`, `release/<version>`, and `skip-changelog`.

11. **Create a GitHub Release**
    After the PR is approved and merged, create a new Release on the
    [GitHub releases page](https://github.com/Code-Vedas/rails_materialized_views/releases).
    Use **tag name** `v<version>` and include the release notes (same as `CHANGELOG.md`).

12. **Publish via GitHub Actions**
    Once the Release is created, GitHub Actions will automatically build
    and publish the gem to RubyGems.org.

13. **Done 🎉**
    Optionally verify the published version:

    ```bash
    gem install mat_views -v <version>
    ```

    and sanity-check a basic rake task in a fresh Rails app.
