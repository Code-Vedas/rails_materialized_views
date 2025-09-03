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

  describe 'validations' do
    it 'fails when name is invalid format' do
      definition.name = 'public.mv_bad' # contains a dot
      res = execute_service

      expect(res).not_to be_success
      expect(res.error).not_to be_nil
      expect(res.error[:message]).to match(/Invalid view name format/i)
      expect(res.error[:class]).to eq('StandardError')
      expect(res.error[:backtrace]).to be_an(Array)
      expect(mv_exists?(relname)).to be(false)
    end

    it 'fails when the view does not exist' do
      # valid name, but we did not create the view
      res = execute_service

      expect(res).not_to be_success
      expect(res.error).not_to be_nil
      expect(res.error[:message]).to match(/does not exist/i)
      expect(res.error[:class]).to eq('StandardError')
      expect(res.error[:backtrace]).to be_an(Array)
      expect(mv_exists?(relname)).to be(false)
    end
  end

  describe 'row count strategy handling' do
    before do
      create_mv!(relname, schema: 'public')
    end

    context 'when row_count_strategy is nil' do
      let(:row_count_strategy) { nil }

      it 'defaults to :none' do
        res = execute_service
        expect(res).to be_success
        expect(res.request[:row_count_strategy]).to eq(:none)
        expect(res.response[:row_count_before]).to eq(-1) # unknown before creation
        expect(res.response[:row_count_after]).to eq(-1) # skiped because :none
        expect(mv_exists?(relname)).to be(true)
      end
    end

    context 'when row_count_strategy is :none' do
      let(:row_count_strategy) { :none }

      it 'skips row count fetching' do
        res = execute_service
        expect(res).to be_success
        expect(res.request[:row_count_strategy]).to eq(:none)
        expect(res.response[:row_count_before]).to eq(-1) # unknown before creation
        expect(res.response[:row_count_after]).to eq(-1) # skiped because :none
        expect(mv_exists?(relname)).to be(true)
      end
    end

    context 'when row_count_strategy is :estimated' do
      let(:row_count_strategy) { :estimated }

      it 'fetches estimated row counts' do
        res = execute_service
        expect(res).to be_success
        expect(res.request[:row_count_strategy]).to eq(:estimated)
        expect(res.response[:row_count_before]).to eq(-1)
        expect(res.response[:row_count_after]).to eq(-1)
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
    end

    it 'refreshes and returns :updated with estimated rows' do
      res = execute_service

      expect(res).to be_success
      expect(res.status).to eq(:updated)
      expect(res.request[:row_count_strategy]).to eq(:estimated)
      expect(res.response[:view]).to eq("public.#{relname}")
      expect(res.response[:row_count_before]).to be_a(Integer)
      expect(res.response[:row_count_after]).to be_a(Integer)
      expect(res.response[:sql]).to eq([%(REFRESH MATERIALIZED VIEW "public"."#{relname}")])
    end
  end

  describe 'unexpected DB error' do
    it 'wraps exception into error response with meta.sql and payload.view' do
      create_mv!(relname, schema: 'public')
      allow(conn).to receive(:schema_search_path).and_return('public')

      allow(ActiveRecord::Base).to receive(:connection).and_wrap_original do |orig, *args|
        c = orig.call(*args)
        allow(c).to receive(:execute).with(%(REFRESH MATERIALIZED VIEW "public"."#{relname}"))
                                     .and_raise(StandardError, 'boom')
        c
      end

      res = execute_service

      expect(res).not_to be_success
      expect(res.error?).to be(true)
      expect(res.error[:message]).to match(/boom/)
      expect(res.error[:class]).to eq('StandardError')
      expect(res.error[:backtrace]).to be_an(Array)
      expect(res.response[:view]).to eq("public.#{relname}")
      expect(res.response[:sql]).to eq([%(REFRESH MATERIALIZED VIEW "public"."#{relname}")])
    end
  end
end
