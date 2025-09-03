# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

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
    User.destroy_all
    5.times { |i| User.create!(name: "User #{i}", email: "email#{i}@example.com") }
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
    conn.execute(%(CREATE UNIQUE INDEX #{idx_name} ON #{conn.quote_table_name("#{schema}.#{rel}")} (#{conn.quote_column_name(column)})))
  end

  describe 'validations' do
    it 'fails when name is invalid format' do
      definition.name = 'public.mv.bad'
      res = execute_service
      expect(res).not_to be_success
      expect(res.error).not_to be_nil
      expect(res.error[:message]).to match(/Invalid view name format/i)
      expect(mv_exists?(relname)).to be(false)
    end

    it 'fails when the view does not exist' do
      res = execute_service
      expect(res).not_to be_success
      expect(res.error).not_to be_nil
      expect(res.error[:message]).to match(/does not exist/i)
      expect(mv_exists?(relname)).to be(false)
    end
  end

  describe 'unique index requirement' do
    it 'errors when no unique index is present' do
      create_mv!(relname, schema: 'public')
      allow(conn).to receive(:schema_search_path).and_return('public')

      res = execute_service

      expect(res).not_to be_success
      expect(res.error).not_to be_nil
      expect(res.error[:message]).to match(/unique index/i)
    end
  end

  describe 'row count strategy handling' do
    before do
      create_mv!(relname, schema: 'public')
      add_unique_index!(relname, schema: 'public', column: 'id')
    end

    context 'when row_count_strategy is nil' do
      let(:row_count_strategy) { nil }

      it 'defaults to :none' do
        res = execute_service
        expect(res).to be_success
        expect(res.request[:row_count_strategy]).to eq(:none)
        expect(res.response[:row_count_before]).to eq(MatViews::Services::BaseService::UNKNOWN_ROW_COUNT) # unknown before creation
        expect(res.response[:row_count_after]).to eq(MatViews::Services::BaseService::UNKNOWN_ROW_COUNT) # skiped because :none
        expect(mv_exists?(relname)).to be(true)
      end
    end

    context 'when row_count_strategy is :none' do
      let(:row_count_strategy) { :none }

      it 'skips row count fetching' do
        res = execute_service
        expect(res).to be_success
        expect(res.request[:row_count_strategy]).to eq(:none)
        expect(res.response[:row_count_before]).to eq(MatViews::Services::BaseService::UNKNOWN_ROW_COUNT) # unknown before creation
        expect(res.response[:row_count_after]).to eq(MatViews::Services::BaseService::UNKNOWN_ROW_COUNT) # skiped because :none
        expect(mv_exists?(relname)).to be(true)
      end
    end

    context 'when row_count_strategy is :estimated' do
      let(:row_count_strategy) { :estimated }

      it 'fetches estimated row counts' do
        res = execute_service
        expect(res).to be_success
        expect(res.request[:row_count_strategy]).to eq(:estimated)
        expect(res.response[:row_count_before]).to be >= 0
        expect(res.response[:row_count_after]).to be >= 0
        expect(mv_exists?(relname)).to be(true)
      end
    end

    context 'when row_count_strategy is :exact' do
      let(:row_count_strategy) { :exact }

      it 'fetches exact row counts' do
        res = execute_service
        expect(res).to be_success
        expect(res.request[:row_count_strategy]).to eq(:exact)
        expect(res.response[:row_count_before]).to be >= 0
        expect(res.response[:row_count_after]).to be >= 0
        expect(mv_exists?(relname)).to be(true)
      end
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

      expect(res).to be_success
      expect(res.status).to eq(:updated)
      expect(res.request[:row_count_strategy]).to eq(:estimated)
      expect(res.request[:concurrent]).to be(true)
      expect(res.response[:view]).to eq("public.#{relname}")
      expect(res.response[:row_count_before]).to be_a(Integer)
      expect(res.response[:row_count_after]).to be_a(Integer)
      expect(res.response[:sql]).to eq([%(REFRESH MATERIALIZED VIEW CONCURRENTLY "public"."#{relname}")])
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

      expect(res).not_to be_success
      expect(res.error).not_to be_nil
      expect(res.error[:message]).to match(/ObjectInUse|being used by another process/i)
      expect(res.error[:class]).to eq('PG::ObjectInUse')
      expect(res.error[:backtrace]).to be_an(Array)
      expect(res.request[:concurrent]).to be(true)
      expect(res.response[:view]).to eq("public.#{relname}")
      expect(res.response[:sql]).to eq([%(REFRESH MATERIALIZED VIEW CONCURRENTLY "public"."#{relname}")])
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

      expect(res).not_to be_success
      expect(res.error).not_to be_nil
      expect(res.error[:message]).to match(/boom/)
      expect(res.error[:class]).to eq('StandardError')
      expect(res.error[:backtrace]).to be_an(Array)
      expect(res.request[:concurrent]).to be(true)
      expect(res.response[:view]).to eq("public.#{relname}")
      expect(res.response[:sql]).to eq([%(REFRESH MATERIALIZED VIEW CONCURRENTLY "public"."#{relname}")])
    end
  end
end
