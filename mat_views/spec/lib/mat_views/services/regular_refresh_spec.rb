# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::Services::RegularRefresh do
  let(:conn) { ActiveRecord::Base.connection }
  let(:relname) { 'mv_regular_refresh_spec' }
  let(:qualified) { "public.#{relname}" }

  let(:definition) do
    build(:mat_view_definition,
          name: relname,
          sql: 'SELECT id FROM users',
          refresh_strategy: :regular,
          unique_index_columns: [])
  end

  let(:row_count_strategy) { :estimated }
  let(:runner) { described_class.new(definition, row_count_strategy:) }
  let(:execute_service) { runner.run }

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

  describe 'validations' do
    it 'fails when name is invalid format' do
      definition.name = 'public.mv_bad' # contains a dot
      res = execute_service
      expect(res.error?).to be(true)
      expect(res.error).to match(/Invalid view name format/i)
      expect(mv_exists?(relname)).to be(false)
    end

    it 'fails when the view does not exist' do
      # valid name, but we did not create the view
      res = execute_service
      expect(res.error?).to be(true)
      expect(res.error).to match(/does not exist/i)
      expect(mv_exists?(relname)).to be(false)
    end
  end

  describe 'successful refresh' do
    describe 'estimated row count (default), schema from search_path' do
      it 'refreshes and returns :updated with estimated rows and meta' do
        create_mv!(relname, schema: 'public')
        allow(conn).to receive(:schema_search_path).and_return('public')

        res = execute_service

        expect(res.status).to eq(:updated)
        expect(res.payload[:view]).to eq("public.#{relname}")
        expect(res.payload[:rows_count]).to be_a(Integer) # reltuples may be 0+
        expect(res.meta[:row_count_strategy]).to eq(:estimated)
        # quoted relation in SQL meta
        expect(res.meta[:sql]).to eq(%(REFRESH MATERIALIZED VIEW "public"."#{relname}"))
      end
    end

    describe 'exact row count' do
      let(:row_count_strategy) { :exact }

      it 'uses COUNT(*) and returns the exact number' do
        create_mv!(relname, schema: 'public')
        allow(conn).to receive(:schema_search_path).and_return('public')

        res = execute_service

        expect(res).to be_success
        expect(res.payload[:rows_count]).to be_a(Integer)
        expect(res.meta[:row_count_strategy]).to eq(:exact)
      end
    end

    describe 'unknown row_count_strategy symbol' do
      let(:row_count_strategy) { :bogus }

      it 'includes rows_count: nil (strategy truthy but unrecognized)' do
        create_mv!(relname, schema: 'public')
        allow(conn).to receive(:schema_search_path).and_return('public')

        res = execute_service

        expect(res).to be_success
        expect(res.payload).to include(rows_count: nil)
        expect(res.meta[:row_count_strategy]).to eq(:bogus)
      end
    end

    describe 'no row count requested (nil)' do
      let(:row_count_strategy) { nil }

      it 'does not compute or include rows_count' do
        create_mv!(relname, schema: 'public')
        allow(conn).to receive(:schema_search_path).and_return('public')

        res = execute_service

        expect(res).to be_success
        expect(res.payload).not_to have_key(:rows_count)
        expect(res.meta[:row_count_strategy]).to be_nil
      end
    end
  end

  describe 'schema_search_path resolution' do
    before { create_mv!(relname, schema: 'public') }

    it 'falls back to public when search_path is empty' do
      allow(conn).to receive(:schema_search_path).and_return('')
      res = execute_service
      expect(res).to be_success
      expect(res.payload[:view]).to eq("public.#{relname}")
    end

    it 'ignores non-existent schemas and falls back to public' do
      allow(conn).to receive(:schema_search_path).and_return('other_schema')
      # to_regnamespace(other_schema) should be NULL → fallback to public
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
      # Most test DBs do not have a schema named current_user; this exercises
      # resolve_schema_token + schema_exists? + public fallback.
      res = execute_service
      expect(res).to be_success
      expect(res.payload[:view]).to eq("public.#{relname}")
    end
  end

  describe 'unexpected DB error' do
    it 'wraps exception into error response with meta.sql and payload.view' do
      create_mv!(relname, schema: 'public')
      allow(conn).to receive(:schema_search_path).and_return('public')

      # Make execute raise to exercise the rescue path.
      allow(ActiveRecord::Base).to receive(:connection).and_wrap_original do |orig, *args|
        c = orig.call(*args)
        allow(c).to receive(:execute).with(%(REFRESH MATERIALIZED VIEW "public"."#{relname}"))
                                     .and_raise(StandardError, 'boom')
        c
      end

      res = execute_service
      expect(res.error?).to be(true)
      expect(res.error).to match(/StandardError: boom/)
      expect(res.payload[:view]).to eq("public.#{relname}")
      expect(res.meta[:sql]).to eq(%(REFRESH MATERIALIZED VIEW "public"."#{relname}"))
    end
  end
end
