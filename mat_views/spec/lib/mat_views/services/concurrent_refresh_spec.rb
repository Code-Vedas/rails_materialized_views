# frozen_string_literal: true

RSpec.describe MatViews::Services::ConcurrentRefresh do
  let(:conn)     { ActiveRecord::Base.connection }
  let(:relname)  { 'mv_concurrent_refresh_spec' }
  let(:qualified) { "public.#{relname}" }

  let(:definition) do
    build(:mat_view_definition,
          name: relname,
          sql: 'SELECT id FROM users',
          refresh_strategy: :concurrent,
          unique_index_columns: %w[id])
  end

  let(:row_count_strategy) { :estimated }
  let(:runner)             { described_class.new(definition, row_count_strategy:) }
  let(:execute_service)    { runner.run }

  before do
    # start from a clean slate
    conn.execute(%(DROP MATERIALIZED VIEW IF EXISTS public."#{relname}"))
  end

  def mv_exists?(rel, schema: 'public')
    conn.select_value(<<~SQL).to_i.positive?
      SELECT COUNT(*)
      FROM pg_matviews
      WHERE schemaname=#{conn.quote(schema)} AND matviewname=#{conn.quote(rel)}
    SQL
  end

  def create_mv!(rel, schema: 'public')
    quoted_table = conn.quote_table_name("#{schema}.#{rel}")
    conn.execute("CREATE MATERIALIZED VIEW #{quoted_table} AS SELECT id FROM users WITH DATA")
  end

  def add_unique_index!(rel, schema: 'public', column: 'id')
    idx_name = %("#{rel}_uniq_#{column}")
    # Regular (non-concurrent) index is fine for tests; dropping the MV cleans it up.
    conn.execute(%(CREATE UNIQUE INDEX #{idx_name} ON #{conn.quote_table_name("#{schema}.#{rel}")} (#{conn.quote_column_name(column)})))
  end

  describe 'validations' do
    it 'fails when name is invalid format' do
      definition.name = 'public.mv.bad'
      res = execute_service
      expect(res.error?).to be(true)
      expect(res.error).to match(/Invalid view name format/i)
      expect(mv_exists?(relname)).to be(false)
    end

    it 'fails when the view does not exist' do
      res = execute_service
      expect(res.error?).to be(true)
      expect(res.error).to match(/does not exist/i)
      expect(mv_exists?(relname)).to be(false)
    end
  end

  describe 'unique index requirement' do
    it 'errors when no unique index is present' do
      create_mv!(relname, schema: 'public')
      allow(conn).to receive(:schema_search_path).and_return('public')

      res = execute_service

      expect(res.error?).to be(true)
      expect(res.error).to match(/unique index/i)
    end
  end

  describe 'successful refresh' do
    before do
      create_mv!(relname, schema: 'public')
      add_unique_index!(relname, schema: 'public', column: 'id')
      allow(conn).to receive(:schema_search_path).and_return('public')
    end

    it 'refreshes concurrently and returns :updated with estimated rows and meta' do
      res = execute_service

      expect(res.status).to eq(:updated)
      expect(res.payload[:view]).to eq("public.#{relname}")
      expect(res.payload[:rows_count]).to be_a(Integer)
      expect(res.meta[:row_count_strategy]).to eq(:estimated)
      expect(res.meta[:concurrent]).to be(true)
      expect(res.meta[:sql]).to eq(%(REFRESH MATERIALIZED VIEW CONCURRENTLY "public"."#{relname}"))
    end

    describe 'exact row count' do
      let(:row_count_strategy) { :exact }

      it 'uses COUNT(*) and returns the exact number' do
        res = execute_service
        expect(res).to be_success
        expect(res.payload[:rows_count]).to be_a(Integer)
        expect(res.meta[:row_count_strategy]).to eq(:exact)
      end
    end

    describe 'unknown row_count_strategy symbol' do
      let(:row_count_strategy) { :bogus }

      it 'includes rows_count: nil when strategy is unrecognized' do
        res = execute_service
        expect(res).to be_success
        expect(res.payload).to include(rows_count: nil)
        expect(res.meta[:row_count_strategy]).to eq(:bogus)
      end
    end

    describe 'no row count requested (nil)' do
      let(:row_count_strategy) { nil }

      it 'does not include rows_count' do
        res = execute_service
        expect(res).to be_success
        expect(res.payload).not_to have_key(:rows_count)
        expect(res.meta[:row_count_strategy]).to be_nil
      end
    end
  end

  describe 'schema_search_path resolution' do
    before do
      create_mv!(relname, schema: 'public')
      add_unique_index!(relname, schema: 'public', column: 'id')
    end

    it 'falls back to public when search_path is empty' do
      allow(conn).to receive(:schema_search_path).and_return('')
      res = execute_service
      expect(res).to be_success
      expect(res.payload[:view]).to eq("public.#{relname}")
    end

    it 'ignores non-existent schemas and falls back to public' do
      allow(conn).to receive(:schema_search_path).and_return('other_schema')
      res = execute_service
      expect(res).to be_success
      expect(res.payload[:view]).to eq("public.#{relname}")
    end

    it 'handles quoted tokens' do
      allow(conn).to receive(:schema_search_path).and_return('"public"')
      res = execute_service
      expect(res).to be_success
      expect(res.payload[:view]).to eq("public.#{relname}")
    end

    it 'handles $user token; uses public when user schema is absent' do
      allow(conn).to receive(:schema_search_path).and_return('$user,public')
      res = execute_service
      expect(res).to be_success
      expect(res.payload[:view]).to eq("public.#{relname}")
    end
  end

  describe 'locking / DB errors' do
    before do
      create_mv!(relname, schema: 'public')
      add_unique_index!(relname, schema: 'public', column: 'id')
      allow(conn).to receive(:schema_search_path).and_return('public')
    end

    it 'wraps PG::ObjectInUse into error response with meta.sql and payload.view' do
      allow(ActiveRecord::Base).to receive(:connection).and_wrap_original do |orig, *args|
        c = orig.call(*args)
        allow(c).to receive(:execute)
          .with(%(REFRESH MATERIALIZED VIEW CONCURRENTLY "public"."#{relname}"))
          .and_raise(PG::ObjectInUse, 'relation is being used by another process')
        c
      end

      res = execute_service
      expect(res.error?).to be(true)
      expect(res.error).to match(/ObjectInUse|being used by another process/i)
      expect(res.payload[:view]).to eq("public.#{relname}")
      expect(res.meta[:sql]).to eq(%(REFRESH MATERIALIZED VIEW CONCURRENTLY "public"."#{relname}"))
      expect(res.meta[:concurrent]).to be(true)
    end

    it 'wraps unexpected DB error with backtrace and meta.sql' do
      allow(ActiveRecord::Base).to receive(:connection).and_wrap_original do |orig, *args|
        c = orig.call(*args)
        allow(c).to receive(:execute)
          .with(%(REFRESH MATERIALIZED VIEW CONCURRENTLY "public"."#{relname}"))
          .and_raise(StandardError, 'boom')
        c
      end

      res = execute_service
      expect(res.error?).to be(true)
      expect(res.error).to match(/StandardError: boom/)
      expect(res.payload[:view]).to eq("public.#{relname}")
      expect(res.meta[:sql]).to eq(%(REFRESH MATERIALIZED VIEW CONCURRENTLY "public"."#{relname}"))
      expect(res.meta[:concurrent]).to be(true)
    end
  end
end
