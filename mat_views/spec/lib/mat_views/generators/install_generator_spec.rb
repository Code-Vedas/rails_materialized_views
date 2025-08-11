# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'generator_spec'
require 'generators/mat_views/install/install_generator'

RSpec.describe MatViews::Generators::InstallGenerator, type: :generator do
  destination File.expand_path(Rails.root.join('tmp', 'mat_views_install_generator'))

  before do
    prepare_destination
    run_generator
  end

  after do
    FileUtils.rm_rf(destination_root)
  end

  it 'creates initializer file' do
    file = File.join(destination_root, 'config', 'initializers', 'mat_views.rb')
    expect(File.read(file)).to include('MatViews.configure')
  end

  it 'creates migration for mat_view_definitions' do
    migration = Dir.glob(File.join(destination_root, 'db/migrate/*_create_mat_view_definitions.rb')).first
    expect(File.read(migration)).to include('create_table :mat_view_definitions')
  end

  it 'creates migration for mat_view_refresh_runs' do
    migration = Dir.glob(File.join(destination_root, 'db/migrate/*_create_mat_view_refresh_runs.rb')).first
    expect(File.read(migration)).to include('create_table :mat_view_refresh_runs')
  end

  it 'creates migration for mat_view_create_runs' do
    migration = Dir.glob(File.join(destination_root, 'db/migrate/*_create_mat_view_create_runs.rb')).first
    expect(File.read(migration)).to include('create_table :mat_view_create_runs')
  end
end
