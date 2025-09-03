# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

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

  describe 'successful swap' do
    before do
      create_mv!(relname, schema: 'public')
      allow(conn).to receive(:schema_search_path).and_return('public')
    end

    it 'rebuilds into a temp MV and atomically swaps it' do
      res = execute_service

      expect(res).to be_success
      expect(res.status).to eq(:updated)
      expect(res.request[:swap]).to be(true)
      expect(res.request[:row_count_strategy]).to eq(:estimated)
      expect(res.response[:sql].count).to eq(4)
      expect(res.response[:view]).to eq("public.#{relname}")
      expect(res.response[:sql].join(' ')).to include('CREATE MATERIALIZED VIEW')
      expect(res.response[:sql].join(' ')).to include('ALTER MATERIALIZED VIEW')
      expect(res.response[:sql].join(' ')).to include('WITH DATA')
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

      expect(res).not_to be_success
      expect(res.error).not_to be_nil
      expect(res.error[:message]).to match(/boom/)
      expect(res.error[:class]).to eq('StandardError')
      expect(res.error[:backtrace]).to be_an(Array)
      expect(res.response[:view]).to eq("public.#{relname}")
      expect(res.request[:swap]).to be(true)
    end
  end
end
