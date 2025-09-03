# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::Services::DeleteView do
  let(:conn) { ActiveRecord::Base.connection }
  let(:relname) { 'mv_delete_view_spec' }
  let(:qualified) { "public.#{relname}" }

  let(:definition) do
    build(:mat_view_definition,
          name: relname,
          sql: 'SELECT id FROM users',
          refresh_strategy: :regular,
          unique_index_columns: [])
  end
  let(:row_count_strategy) { :estimated }
  let(:cascade) { false }
  let(:runner) { described_class.new(definition, cascade: cascade, row_count_strategy: row_count_strategy) }
  let(:execute_service) { runner.run }

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
    conn.execute("ANALYZE #{quoted_table}")
  end

  before do
    User.destroy_all
    5.times { |i| User.create!(name: "User #{i}", email: "email#{i}@example.com") }
    conn.execute(%(DROP MATERIALIZED VIEW IF EXISTS public."#{relname}" CASCADE))
    conn.execute(%(DROP VIEW IF EXISTS public."#{relname}_dep" CASCADE))
  end

  it 'deletes an existing matview (RESTRICT default) when no deps' do
    create_mv!(relname)
    expect(mv_exists?(relname)).to be(true)

    res = execute_service

    expect(res).to be_success
    expect(res.status).to eq(:deleted)
    expect(res.response[:view]).to eq(qualified)
    expect(res.response[:sql]).to eq([%(DROP MATERIALIZED VIEW IF EXISTS "public"."#{relname}" RESTRICT)])
    expect(mv_exists?(relname)).to be(false)
  end

  it 'skips when not present' do
    expect(mv_exists?(relname)).to be(false)

    res = execute_service

    expect(res).to be_success
    expect(res.status).to eq(:skipped)
    expect(res.response[:view]).to eq(qualified)
    expect(res.response[:sql]).to eq([%(DROP MATERIALIZED VIEW IF EXISTS "public"."#{relname}" RESTRICT)])
  end

  describe 'row count strategy handling' do
    before do
      create_mv!(relname)
    end

    context 'when row_count_strategy is nil' do
      let(:row_count_strategy) { nil }

      it 'defaults to :none' do
        res = execute_service

        expect(res).to be_success
        expect(res.request[:row_count_strategy]).to eq(:none)
        expect(res.response[:row_count_before]).to eq(MatViews::Services::BaseService::UNKNOWN_ROW_COUNT)
        expect(res.response[:row_count_after]).to eq(MatViews::Services::BaseService::UNKNOWN_ROW_COUNT) # view is gone
        expect(mv_exists?(relname)).to be(false)
      end
    end

    context 'when row_count_strategy is :none' do
      let(:row_count_strategy) { :none }

      it 'skips row count fetching' do
        res = execute_service

        expect(res).to be_success
        expect(res.request[:row_count_strategy]).to eq(:none)
        expect(res.response[:row_count_before]).to eq(MatViews::Services::BaseService::UNKNOWN_ROW_COUNT)
        expect(res.response[:row_count_after]).to eq(MatViews::Services::BaseService::UNKNOWN_ROW_COUNT) # view is gone
        expect(mv_exists?(relname)).to be(false)
      end
    end

    context 'when row_count_strategy is :estimated' do
      let(:row_count_strategy) { :estimated }

      it 'fetches estimated row counts' do
        res = execute_service

        expect(res).to be_success
        expect(res.request[:row_count_strategy]).to eq(:estimated)
        expect(res.response[:row_count_before]).to be >= 0
        expect(res.response[:row_count_after]).to eq(MatViews::Services::BaseService::UNKNOWN_ROW_COUNT) # view is gone
        expect(mv_exists?(relname)).to be(false)
      end
    end

    context 'when row_count_strategy is :exact' do
      let(:row_count_strategy) { :exact }

      it 'fetches exact row counts' do
        res = execute_service

        expect(res).to be_success
        expect(res.request[:row_count_strategy]).to eq(:exact)
        expect(res.response[:row_count_before]).to be >= 0
        expect(res.response[:row_count_after]).to eq(MatViews::Services::BaseService::UNKNOWN_ROW_COUNT) # view is gone
        expect(mv_exists?(relname)).to be(false)
      end
    end
  end

  describe 'cascade option' do
    before do
      create_mv!(relname)
      conn.execute(%(CREATE VIEW public."#{relname}_dep" AS SELECT * FROM public."#{relname}"))
    end

    context 'when dependencies exist, and cascade is false' do
      let(:cascade) { false }

      it 'errors with helpful message when dependencies exist and cascade=false', :no_txn do
        res = execute_service

        expect(res.error?).to be(true)
        expect(res.error[:message]).to match(/PG::DependentObjectsStillExist: ERROR:  cannot drop materialized view/i)
        expect(res.error[:class]).to eq('ActiveRecord::StatementInvalid')
        expect(res.error[:backtrace]).to be_an(Array)
        expect(mv_exists?(relname)).to be(true) # still there
      end
    end

    context 'when dependencies exist, and cascade is true' do
      let(:cascade) { true }

      it 'drops with cascade=true even if dependencies exist' do
        res = execute_service

        expect(res).to be_success
        expect(res.status).to eq(:deleted)
        expect(mv_exists?(relname)).to be(false)
      end
    end
  end

  it 'fails fast on invalid name format' do
    definition.name = 'public.bad' # contains a dot
    res = execute_service

    expect(res).not_to be_success
    expect(res.error?).to be(true)
    expect(res.error[:message]).to match(/Invalid view name format/i)
    expect(res.error[:class]).to eq('StandardError')
    expect(res.error[:backtrace]).to be_an(Array)
  end

  context 'when standard error is raised' do
    before do
      allow(ActiveRecord::Base).to receive(:connection).and_wrap_original do |orig, *args|
        c = orig.call(*args)
        allow(c).to receive(:execute).with(%(DROP MATERIALIZED VIEW IF EXISTS "public"."#{relname}" RESTRICT))
                                     .and_raise(StandardError, 'boom')
        c
      end
    end

    it 'returns an error response with backtrace' do
      create_mv!(relname)
      res = execute_service

      expect(res).not_to be_success
      expect(res.error?).to be(true)
      expect(res.error[:message]).to eq('boom')
      expect(res.error[:class]).to eq('StandardError')
      expect(res.error[:backtrace]).to be_an(Array)
      expect(res.response[:view]).to eq(qualified)
    end
  end
end
