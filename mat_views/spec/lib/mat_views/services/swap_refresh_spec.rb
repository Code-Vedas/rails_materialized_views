# frozen_string_literal: true

RSpec.describe MatViews::Services::SwapRefresh do
  let(:conn)      { ActiveRecord::Base.connection }
  let(:relname)   { 'mv_swap_refresh_spec' }
  let(:qualified) { "public.#{relname}" }

  let(:definition) do
    build(:mat_view_definition,
          name: relname,
          sql: 'SELECT id FROM users',
          refresh_strategy: :swap,
          unique_index_columns: [])
  end

  let(:row_count_strategy) { :estimated }
  let(:runner)             { described_class.new(definition, row_count_strategy:) }
  let(:execute_service)    { runner.run }

  before do
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

  def unique_index_count(rel, schema: 'public')
    conn.select_value(<<~SQL).to_i
      SELECT COUNT(*)
      FROM pg_index i
      JOIN pg_class c ON c.oid = i.indrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = #{conn.quote(schema)}
        AND c.relname = #{conn.quote(rel)}
        AND i.indisunique = TRUE
    SQL
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

  describe 'successful swap' do
    before do
      create_mv!(relname, schema: 'public')
      allow(conn).to receive(:schema_search_path).and_return('public')
    end

    it 'rebuilds into a temp MV and atomically swaps it' do
      res = execute_service

      expect(res).to be_success
      expect(res.status).to eq(:updated)
      expect(res.payload[:view]).to eq("public.#{relname}")
      expect(res.payload[:rows_count]).to be_a(Integer) # estimated by default
      expect(res.meta[:swap]).to be(true)
      expect(res.meta[:steps]).to be_an(Array)
      expect(res.meta[:steps].count).to eq(4)
      # should include a CREATE MATERIALIZED VIEW ... WITH DATA and two RENAMEs
      expect(res.meta[:steps].join(' ')).to include('CREATE MATERIALIZED VIEW')
      expect(res.meta[:steps].join(' ')).to include('ALTER MATERIALIZED VIEW')
      expect(res.meta[:steps].join(' ')).to include('WITH DATA')
    end

    describe 'exact row count' do
      let(:row_count_strategy) { :exact }

      it 'returns an exact COUNT(*)' do
        res = execute_service
        expect(res).to be_success
        expect(res.payload[:rows_count]).to be_a(Integer)
        expect(res.meta[:row_count_strategy]).to eq(:exact)
      end
    end

    describe 'unknown row_count_strategy symbol' do
      let(:row_count_strategy) { :bogus }

      it 'still succeeds and includes rows_count: nil' do
        res = execute_service
        expect(res).to be_success
        expect(res.payload).to include(rows_count: nil)
        expect(res.meta[:row_count_strategy]).to eq(:bogus)
      end
    end

    describe 'no row count requested (nil)' do
      let(:row_count_strategy) { nil }

      it 'omits rows_count' do
        res = execute_service
        expect(res).to be_success
        expect(res.payload).not_to have_key(:rows_count)
        expect(res.meta[:row_count_strategy]).to be_nil
      end
    end
  end

  describe 'recreating declared indexes' do
    before do
      create_mv!(relname, schema: 'public')
      allow(conn).to receive(:schema_search_path).and_return('public')
    end

    it 'creates a unique index when unique_index_columns are provided' do
      definition.unique_index_columns = %w[id]

      pre_count = unique_index_count(relname)
      res = execute_service
      post_count = unique_index_count(relname)

      expect(res).to be_success
      expect(post_count).to be >= (pre_count + 1)
    end

    it 'supports multi-column unique indexes' do
      definition.unique_index_columns = %w[id id]
      res = execute_service
      expect(res).to be_success
      expect(unique_index_count(relname)).to be >= 1
    end
  end

  describe 'schema_search_path resolution' do
    before do
      create_mv!(relname, schema: 'public')
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

  describe 'unexpected DB error' do
    it 'wraps exception into error response with meta.steps and payload.view' do
      create_mv!(relname, schema: 'public')
      allow(conn).to receive(:schema_search_path).and_return('public')

      # Force failure on the first CREATE to exercise rescue path
      allow(ActiveRecord::Base).to receive(:connection).and_wrap_original do |orig, *args|
        c = orig.call(*args)
        allow(c).to receive(:execute)
          .with(a_string_matching(/\ACREATE MATERIALIZED VIEW .* WITH DATA\z/))
          .and_raise(StandardError, 'boom')
        c
      end

      res = execute_service
      expect(res.error?).to be(true)
      expect(res.error).to match(/StandardError: boom/)
      expect(res.payload[:view]).to eq("public.#{relname}")
      expect(res.meta[:steps]).to be_an(Array)
      expect(res.meta[:swap]).to be(true)
    end
  end
end
