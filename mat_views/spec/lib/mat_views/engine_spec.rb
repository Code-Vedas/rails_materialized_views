# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::Engine, type: :engine do
  it 'inherits from Rails::Engine' do
    expect(described_class < Rails::Engine).to be(true)
  end

  it 'isolates the MatViews namespace' do
    expect(described_class.isolated).to be(true)
  end

  describe '.default_locale' do
    it 'returns :en' do
      expect(described_class.default_locale).to eq(:en)
    end
  end

  describe 'project metadata helpers' do
    let(:fake_metadata) do
      {
        'documentation_uri' => 'https://docs.example.com',
        'bug_tracker_uri' => 'https://bugs.example.com',
        'support_uri' => 'https://support.example.com',
        'rubygems_uri' => 'https://rubygems.org/gems/mat_views'
      }
    end

    let(:fake_spec) do
      instance_double(
        Gem::Specification,
        name: 'mat_views',
        homepage: 'https://example.com/mat_views',
        metadata: fake_metadata
      )
    end

    context 'when a loaded spec is present' do
      before { allow(described_class).to receive(:loaded_spec).and_return(fake_spec) }

      it { expect(described_class.project_name).to eq('mat_views') }
      it { expect(described_class.project_homepage).to eq('https://example.com/mat_views') }
      it { expect(described_class.documentation_uri).to eq('https://docs.example.com') }
      it { expect(described_class.bug_tracker_uri).to eq('https://bugs.example.com') }
      it { expect(described_class.support_uri).to eq('https://support.example.com') }
      it { expect(described_class.rubygems_uri).to eq('https://rubygems.org/gems/mat_views') }
    end

    context 'when no loaded spec is present' do
      before { allow(described_class).to receive(:loaded_spec).and_return(nil) }

      it 'returns nil for spec-derived fields' do
        expect(described_class.project_name).to be_nil
        expect(described_class.project_homepage).to be_nil
        expect(described_class.documentation_uri).to be_nil
        expect(described_class.bug_tracker_uri).to be_nil
        expect(described_class.support_uri).to be_nil
        expect(described_class.rubygems_uri).to be_nil
      end
    end

    it 'returns MatViews::VERSION for project_version' do
      expect(described_class.project_version).to eq(MatViews::VERSION)
    end
  end

  describe 'mat_views.importmap' do
    let(:engine) { described_class.instance }
    let(:engine_initializer) { engine.initializers.find { |i| i.name == 'mat_views.importmap' } }

    # Anonymous fakes (no leaky constants)
    let(:fake_sweeper_class) do
      Class.new do
        attr_reader :executed

        def execute_if_updated = (@executed = true)
      end
    end

    let(:fake_map_class) do
      sweeper_class = fake_sweeper_class
      Class.new do
        attr_reader :drawn_with, :watches, :sweeper

        define_method(:initialize) { @sweeper = sweeper_class.new }
        define_method(:draw) { |path| @drawn_with = path }
        define_method(:cache_sweeper) do |watches: nil|
          @watches = watches if watches
          @sweeper
        end
      end
    end

    let(:fake_controller_base) do
      Class.new do
        class << self
          attr_reader :before_actions

          def before_action(&blk)
            (@before_actions ||= []) << blk
          end
        end
      end
    end

    around do |ex|
      prev = MatViews.importmap
      MatViews.importmap = nil
      ex.run
      MatViews.importmap = prev
    end

    context 'when Importmap is defined (then-branch)' do
      before do
        stub_const('Importmap', Module.new)
        stub_const('Importmap::Map', fake_map_class)

        # Execute the initializer block with self=fake_controller_base (no args),
        # which matches ActiveSupport.on_load semantics.
        allow(ActiveSupport).to receive(:on_load).with(:action_controller_base) do |&blk|
          fake_controller_base.class_eval(&blk)
        end

        # Spy on puts (quiet output + message spy)
        allow($stdout).to receive(:puts)
      end

      it 'builds the map, draws config, sets sweeper, installs before_action, and calls puts' do
        expect do
          engine_initializer.run(instance_double(Rails::Application))
        end.to change(MatViews, :importmap).from(nil)

        map = MatViews.importmap
        expect(map).to be_a(fake_map_class)
        expect(map.drawn_with).to eq(described_class.root.join('config/importmap.rb'))
        expect(map.watches).to eq(described_class.root.join('app/javascript'))

        # before_action triggers the sweeper when called
        blk = fake_controller_base.before_actions.first
        sweeper = map.cache_sweeper
        expect(sweeper.executed).to be_nil
        blk.call
        expect(sweeper.executed).to be(true)
      end
    end

    context 'when Importmap is NOT defined (else-branch via guard next)' do
      before do
        hide_const('Importmap')
        allow(ActiveSupport).to receive(:on_load) # spy only
        allow($stdout).to receive(:puts)
      end

      it 'is a no-op: does not set importmap, does not call on_load, does not puts' do
        expect do
          engine_initializer.run(instance_double(Rails::Application))
        end.not_to change(MatViews, :importmap)

        expect(ActiveSupport).not_to have_received(:on_load)
        expect($stdout).not_to have_received(:puts)
      end
    end
  end
end
