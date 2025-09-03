# frozen_string_literal: true

require 'rake'
require 'stringio'

RSpec.describe 'mat_views rake tasks', type: :rake do # rubocop:disable RSpec/DescribeClass
  let(:no_op_func) { ->(*) {} }
  let(:fake_logger) { instance_spy(Logger, info: no_op_func, warn: no_op_func, error: no_op_func, debug: no_op_func) }

  before do
    allow($stdout).to receive(:print)
    allow($stdout).to receive(:flush)
    allow(Rails).to receive(:logger).and_return(fake_logger)
    allow(MatViews::Jobs::Adapter).to receive(:enqueue)
  end

  def invoke(task_name, *args)
    task = Rake::Task[task_name]
    task.reenable
    task.invoke(*args)
  end

  def with_env(vars)
    old = {}
    vars.each do |key, value|
      old[key] = ENV.key?(key) ? ENV[key] : :__absent__
      ENV[key] = value
    end
    yield
  ensure
    old.each { |key, value| value == :__absent__ ? ENV.delete(key) : ENV[key] = value }
  end

  def with_stdin(input)
    orig = $stdin
    $stdin = StringIO.new(input)
    yield
  ensure
    $stdin = orig
  end

  # ───────────── CREATE ─────────────

  describe 'mat_views:create_by_name', type: :rake do
    let!(:defn) { create(:mat_view_definition, name: 'sales_daily') }

    it 'enqueues CreateViewJob (default force=false) and skips confirm with --yes' do
      invoke('mat_views:create_by_name', defn.name, nil, '--yes')
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::CreateViewJob, queue: anything, args: [defn.id, false])
    end

    it 'passes force=true' do
      invoke('mat_views:create_by_name', defn.name, 'true', '--yes')
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::CreateViewJob, queue: anything, args: [defn.id, true])
    end

    it 'accepts YES=1 via env to skip confirm' do
      with_env('YES' => '1') { invoke('mat_views:create_by_name', defn.name, nil, nil) }
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::CreateViewJob, queue: anything, args: [defn.id, false])
    end

    it 'accepts FORCE=true via env when arg is nil' do
      with_env('YES' => '1', 'FORCE' => 'true') { invoke('mat_views:create_by_name', defn.name, nil, nil) }
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::CreateViewJob, queue: anything, args: [defn.id, true])
    end

    it 'prompts and aborts when confirm is declined' do
      expect do
        with_stdin("\n") { invoke('mat_views:create_by_name', defn.name, nil, nil) }
      end.to raise_error(/Aborted/i)
      expect(MatViews::Jobs::Adapter).not_to have_received(:enqueue)
    end

    # NEW: covers case where $stdin.gets returns nil (EOF)
    it 'aborts when STDIN returns nil (EOF)' do
      allow($stdin).to receive(:gets).and_return(nil)
      expect do
        invoke('mat_views:create_by_name', defn.name, nil, nil)
      end.to raise_error(/Aborted/i)
      expect(MatViews::Jobs::Adapter).not_to have_received(:enqueue)
    end

    it 'raises when name unknown' do
      expect do
        invoke('mat_views:create_by_name', 'does_not_exist', nil, '--yes')
      end.to raise_error(/No MatViews::MatViewDefinition/)
    end

    it 'raises a specific error when schema-qualified MV exists but no definition' do
      allow(ActiveRecord::Base).to receive(:connection).and_wrap_original do |orig, *args|
        c = orig.call(*args)
        allow(c).to receive(:select_value).and_wrap_original do |orig_sv, sql|
          /FROM pg_matviews/i.match?(sql.to_s) ? 1 : orig_sv.call(sql)
        end
        c
      end

      expect do
        invoke('mat_views:create_by_name', 'public.unknown_mv', nil, '--yes')
      end.to raise_error(/exists, but no MatViews::MatViewDefinition/)
    end

    it 'errors when view_name is blank' do
      expect do
        invoke('mat_views:create_by_name', '', nil, '--yes')
      end.to raise_error(/view_name is required/)
    end

    it 'errors when view_name is nil' do
      expect do
        invoke('mat_views:create_by_name')
      end.to raise_error(/view_name is required/)
    end
  end

  describe 'mat_views:create_by_id', type: :rake do
    let!(:defn) { create(:mat_view_definition) }

    it 'enqueues CreateViewJob (default force=false) and skips confirm with --yes' do
      invoke('mat_views:create_by_id', defn.id.to_s, nil, '--yes')
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::CreateViewJob, queue: anything, args: [defn.id, false])
    end

    it 'passes force=true' do
      invoke('mat_views:create_by_id', defn.id.to_s, 'true', '--yes')
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::CreateViewJob, queue: anything, args: [defn.id, true])
    end

    it "prompts and proceeds when user types 'y'" do
      with_stdin("y\n") { invoke('mat_views:create_by_id', defn.id.to_s, nil, nil) }
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::CreateViewJob, queue: anything, args: [defn.id, false])
    end

    it 'raises for unknown id' do
      expect do
        invoke('mat_views:create_by_id', '999999', nil, '--yes')
      end.to raise_error(/No MatViews::MatViewDefinition/)
    end

    it 'errors when definition_id is missing/blank' do
      expect do
        invoke('mat_views:create_by_id', '', nil, '--yes')
      end.to raise_error(/mat_views:create_by_id requires a definition_id parameter/)
    end
  end

  describe 'mat_views:create_all', type: :rake do
    it 'enqueues for each definition and skips confirm with --yes' do
      defs = create_list(:mat_view_definition, 2)
      invoke('mat_views:create_all', nil, '--yes')

      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::CreateViewJob, queue: anything, args: [defs[0].id, false])
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::CreateViewJob, queue: anything, args: [defs[1].id, false])
    end

    it 'passes force=true for all' do
      defs = create_list(:mat_view_definition, 2)
      invoke('mat_views:create_all', 'true', '--yes')

      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::CreateViewJob, queue: anything, args: [defs[0].id, true])
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::CreateViewJob, queue: anything, args: [defs[1].id, true])
    end

    it 'honors YES=1 env to skip confirm' do
      defs = create_list(:mat_view_definition, 1)
      with_env('YES' => '1') { invoke('mat_views:create_all', nil, nil) }

      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::CreateViewJob, queue: anything, args: [defs.first.id, false])
    end

    it 'logs a message when there are no definitions' do
      expect { invoke('mat_views:create_all', nil, '--yes') }.not_to raise_error
      expect(fake_logger).to have_received(:info).with(/\[mat_views\] No mat view definitions found\./)
    end
  end

  # ───────────── REFRESH ─────────────

  describe 'mat_views:refresh_by_name', type: :rake do
    let!(:defn) { create(:mat_view_definition, name: 'sales_daily') }

    it 'enqueues RefreshViewJob (default estimated) and skips confirm with --yes' do
      invoke('mat_views:refresh_by_name', defn.name, nil, '--yes')
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::RefreshViewJob, queue: anything, args: [defn.id, :estimated])
    end

    it 'passes explicit row_count_strategy arg' do
      invoke('mat_views:refresh_by_name', defn.name, 'exact', '--yes')
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::RefreshViewJob, queue: anything, args: [defn.id, :exact])
    end

    it 'honors ROW_COUNT_STRATEGY=exact env when arg is nil' do
      with_env('YES' => '1', 'ROW_COUNT_STRATEGY' => 'exact') do
        invoke('mat_views:refresh_by_name', defn.name, nil, nil)
      end
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::RefreshViewJob, queue: anything, args: [defn.id, :exact])
    end

    it "accepts 'y' to skip confirm" do
      invoke('mat_views:refresh_by_name', defn.name, nil, 'y')
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::RefreshViewJob, queue: anything, args: [defn.id, :estimated])
    end

    it 'raises when name unknown' do
      expect do
        invoke('mat_views:refresh_by_name', 'does_not_exist', nil, '--yes')
      end.to raise_error(/No MatViews::MatViewDefinition/)
    end
  end

  describe 'mat_views:refresh_by_id', type: :rake do
    let!(:defn) { create(:mat_view_definition) }

    it 'enqueues RefreshViewJob (default estimated) and skips confirm with --yes' do
      invoke('mat_views:refresh_by_id', defn.id.to_s, nil, '--yes')
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::RefreshViewJob, queue: anything, args: [defn.id, :estimated])
    end

    it 'passes explicit row_count_strategy' do
      invoke('mat_views:refresh_by_id', defn.id.to_s, 'exact', '--yes')
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::RefreshViewJob, queue: anything, args: [defn.id, :exact])
    end

    it "prompts and proceeds when user types 'y'" do
      with_stdin("y\n") { invoke('mat_views:refresh_by_id', defn.id.to_s, nil, nil) }
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::RefreshViewJob, queue: anything, args: [defn.id, :estimated])
    end

    it 'raises for unknown id' do
      expect do
        invoke('mat_views:refresh_by_id', '999999', nil, '--yes')
      end.to raise_error(/No MatViews::MatViewDefinition/)
    end

    it 'errors when definition_id is missing/blank' do
      expect do
        invoke('mat_views:refresh_by_id', '', nil, '--yes')
      end.to raise_error(/mat_views:refresh_by_id requires a definition_id parameter/)
    end
  end

  describe 'mat_views:refresh_all', type: :rake do
    it 'enqueues for each definition and skips confirm with --yes' do
      defs = create_list(:mat_view_definition, 3)
      invoke('mat_views:refresh_all', nil, '--yes')

      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::RefreshViewJob, queue: anything, args: [defs[0].id, :estimated])
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::RefreshViewJob, queue: anything, args: [defs[1].id, :estimated])
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::RefreshViewJob, queue: anything, args: [defs[2].id, :estimated])
    end

    it 'passes explicit row_count_strategy for all' do
      defs = create_list(:mat_view_definition, 2)
      invoke('mat_views:refresh_all', 'exact', '--yes')

      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::RefreshViewJob, queue: anything, args: [defs[0].id, :exact])
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::RefreshViewJob, queue: anything, args: [defs[1].id, :exact])
    end

    it 'logs a message when there are no definitions' do
      expect { invoke('mat_views:refresh_all', nil, '--yes') }.not_to raise_error
      expect(fake_logger).to have_received(:info).with(/\[mat_views\] No mat view definitions found\./)
    end
  end

  # ───────────── DELETE ─────────────

  describe 'mat_views:delete_by_name', type: :rake do
    let!(:defn) { create(:mat_view_definition, name: 'sales_daily') }

    it 'enqueues DeleteViewJob (default cascade=false) and skips confirm with --yes' do
      invoke('mat_views:delete_by_name', defn.name, nil, '--yes')
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::DeleteViewJob, queue: anything, args: [defn.id, false])
    end

    it 'passes cascade=true' do
      invoke('mat_views:delete_by_name', defn.name, 'true', '--yes')
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::DeleteViewJob, queue: anything, args: [defn.id, true])
    end

    it 'accepts YES=1 via env to skip confirm' do
      with_env('YES' => '1') { invoke('mat_views:delete_by_name', defn.name, nil, nil) }
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::DeleteViewJob, queue: anything, args: [defn.id, false])
    end

    it 'prompts and aborts when confirm is declined' do
      expect do
        with_stdin("\n") { invoke('mat_views:delete_by_name', defn.name, nil, nil) }
      end.to raise_error(/Aborted/i)
      expect(MatViews::Jobs::Adapter).not_to have_received(:enqueue)
    end

    it 'aborts when STDIN returns nil (EOF)' do
      allow($stdin).to receive(:gets).and_return(nil)
      expect { invoke('mat_views:delete_by_name', defn.name, nil, nil) }.to raise_error(/Aborted/i)
      expect(MatViews::Jobs::Adapter).not_to have_received(:enqueue)
    end

    it 'raises when name unknown' do
      expect do
        invoke('mat_views:delete_by_name', 'does_not_exist', nil, '--yes')
      end.to raise_error(/No MatViews::MatViewDefinition/)
    end
  end

  describe 'mat_views:delete_by_id', type: :rake do
    let!(:defn) { create(:mat_view_definition) }

    it 'enqueues DeleteViewJob (default cascade=false) and skips confirm with --yes' do
      invoke('mat_views:delete_by_id', defn.id.to_s, nil, '--yes')
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::DeleteViewJob, queue: anything, args: [defn.id, false])
    end

    it 'passes cascade=true' do
      invoke('mat_views:delete_by_id', defn.id.to_s, 'true', '--yes')
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::DeleteViewJob, queue: anything, args: [defn.id, true])
    end

    it "prompts and proceeds when user types 'y'" do
      with_stdin("y\n") { invoke('mat_views:delete_by_id', defn.id.to_s, nil, nil) }
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::DeleteViewJob, queue: anything, args: [defn.id, false])
    end

    it 'raises for unknown id' do
      expect do
        invoke('mat_views:delete_by_id', '999999', nil, '--yes')
      end.to raise_error(/No MatViews::MatViewDefinition/)
    end

    it 'errors when definition_id is missing/blank' do
      expect do
        invoke('mat_views:delete_by_id', '', nil, '--yes')
      end.to raise_error(/mat_views:delete_by_id requires a definition_id parameter/)
    end
  end

  describe 'mat_views:delete_all', type: :rake do
    it 'enqueues for each definition and skips confirm with --yes' do
      defs = create_list(:mat_view_definition, 3)
      invoke('mat_views:delete_all', nil, '--yes')

      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::DeleteViewJob, queue: anything, args: [defs[0].id, false])
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::DeleteViewJob, queue: anything, args: [defs[1].id, false])
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::DeleteViewJob, queue: anything, args: [defs[2].id, false])
    end

    it 'passes cascade=true for all' do
      defs = create_list(:mat_view_definition, 2)
      invoke('mat_views:delete_all', 'true', '--yes')

      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::DeleteViewJob, queue: anything, args: [defs[0].id, true])
      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::DeleteViewJob, queue: anything, args: [defs[1].id, true])
    end

    it 'honors YES=1 env to skip confirm' do
      defs = create_list(:mat_view_definition, 1)
      with_env('YES' => '1') { invoke('mat_views:delete_all', nil, nil) }

      expect(MatViews::Jobs::Adapter).to have_received(:enqueue)
        .with(MatViews::DeleteViewJob, queue: anything, args: [defs.first.id, false])
    end

    it 'logs a message when there are no definitions' do
      expect { invoke('mat_views:delete_all', nil, '--yes') }.not_to raise_error
      expect(fake_logger).to have_received(:info).with(/\[mat_views\] No mat view definitions found\./)
    end
  end
end
