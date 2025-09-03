# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::Services::CreateView do
  let(:conn) { ActiveRecord::Base.connection }
  let(:relname) { 'mv_create_service_spec' }
  let(:qualified) { "public.#{relname}" }

  let(:definition) do
    build(:mat_view_definition,
          name: relname,
          sql: 'SELECT id FROM users',
          refresh_strategy: :regular,
          unique_index_columns: [])
  end

  let(:force) { false }
  let(:row_count_strategy) { :estimated }
  let(:runner) { described_class.new(definition, force: force, row_count_strategy: row_count_strategy) }
  let(:execute_service) { runner.run }

  before do
    User.destroy_all
    5.times { |i| User.create!(name: "User #{i}", email: "email#{i}@exmaple.com") }
    conn.execute(%(DROP MATERIALIZED VIEW IF EXISTS public."#{relname}"))
  end

  def mv_exists?(rel)
    conn.select_value(<<~SQL).to_i.positive?
      SELECT COUNT(*)
      FROM pg_matviews
      WHERE schemaname='public' AND matviewname='#{rel}'
    SQL
  end

  def index_count_for(rel, like)
    conn.select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM pg_indexes
      WHERE schemaname='public' AND tablename='#{rel}' AND indexname LIKE #{conn.quote(like)}
    SQL
  end

  describe 'validations' do
    it 'fails when name is invalid format' do
      definition.name = 'public.mv_bad'
      res = execute_service

      expect(res).not_to be_success
      expect(res.error).not_to be_nil
      expect(res.error[:message]).to match(/Invalid view name format/i)
      expect(mv_exists?(relname)).to be(false)
    end

    it "fails when SQL doesn't start with SELECT" do
      definition.sql = "UPDATE users SET name='x'"
      res = execute_service

      expect(res).not_to be_success
      expect(res.error).not_to be_nil
      expect(res.error[:message]).to match(/SQL must start with SELECT/i)
      expect(mv_exists?(relname)).to be(false)
    end

    it 'requires unique_index_columns when strategy is concurrent' do
      allow(definition).to receive_messages(refresh_strategy: 'concurrent', unique_index_columns: [])
      res = execute_service

      expect(res).not_to be_success
      expect(res.error).not_to be_nil
      expect(res.error[:message]).to match(/requires unique_index_columns/i)
      expect(mv_exists?(relname)).to be(false)
    end
  end

  describe 'fresh create' do
    context 'when row_count_strategy is :exact' do
      let(:row_count_strategy) { :exact }

      it 'creates the matview' do
        res = execute_service

        expect(res).to be_success
        expect(res.response[:view]).to eq(qualified)
        expect(res.response[:sql]).to eq(["CREATE MATERIALIZED VIEW #{conn.quote_table_name(qualified)} AS\n#{definition.sql}\nWITH DATA\n"])
        expect(mv_exists?(relname)).to be(true)
      end
    end
  end

  describe 'row count strategy handling' do
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
        expect(res.response[:row_count_before]).to eq(-1) # unknown before creation
        expect(res.response[:row_count_after]).to eq(-1) # analysis not run yet
        expect(mv_exists?(relname)).to be(true)
      end
    end

    context 'when row_count_strategy is :exact' do
      let(:row_count_strategy) { :exact }

      it 'fetches exact row counts' do
        res = execute_service

        expect(res).to be_success
        expect(res.request[:row_count_strategy]).to eq(:exact)
        expect(res.response[:row_count_before]).to eq(-1) # unknown before creation
        expect(res.response[:row_count_after]).to be >= 0
        expect(mv_exists?(relname)).to be(true)
      end
    end
  end

  describe 'existing view handling' do
    it 'skipped if view exists and force: false' do
      expect(described_class.new(definition, force: true).run.status).to eq(:created)

      res = execute_service

      expect(res).to be_success
      expect(res.status).to eq(:skipped)
      expect(mv_exists?(relname)).to be(true)
    end

    it 'drops and recreates when force: true' do
      expect(described_class.new(definition, force: true).run.status).to eq(:created)
      res = described_class.new(definition, force: true).run

      expect(res).to be_success
      expect(res.status).to eq(:created)
      expect(mv_exists?(relname)).to be(true)
    end
  end

  describe 'strategies on fresh create' do
    it 'regular: creates WITH DATA (queryable immediately)' do
      res = execute_service

      expect(res).to be_success
      expect(mv_exists?(relname)).to be(true)
      rows = conn.select_value("SELECT COUNT(*) FROM #{qualified}").to_i
      expect(rows).to be >= 0 # seeded users may vary; at least it selects
    end

    it 'swap: same as regular at creation time' do
      allow(definition).to receive(:refresh_strategy).and_return('swap')
      res = execute_service

      expect(res).to be_success
      rows = conn.select_value("SELECT COUNT(*) FROM #{qualified}").to_i
      expect(rows).to be >= 0
    end

    it 'concurrent: creates WITH DATA + ensures unique index' do
      allow(definition).to receive_messages(refresh_strategy: 'concurrent', unique_index_columns: %w[id])

      res = execute_service

      expect(res).to be_success
      expect(mv_exists?(relname)).to be(true)
      expect(res.response[:created_indexes]).not_to be_nil

      # index exists (concurrently if no tx; non-concurrent if inside tx)
      expect(index_count_for(relname, "public_#{relname}_uniq_id%")).to eq(1)

      # view is already populated (WITH DATA)
      rows = conn.select_value("SELECT COUNT(*) FROM #{qualified}").to_i
      expect(rows).to be >= 0
    end
  end

  describe 'pg_idle? detection' do
    subject(:service) { described_class.new(definition, force: force) }

    let(:ar_conn) { ActiveRecord::Base.connection }
    let(:pg_conn) { instance_double(PG::Connection) }

    before do
      allow(ar_conn).to receive(:raw_connection).and_return(pg_conn)
      allow(ar_conn).to receive(:execute).and_call_original
    end

    # when pg_idle?, index is created CONCURRENTLY
    # when not pg_idle?, index is created without CONCURRENTLY

    context 'when transaction_status is idle' do
      before do
        allow(pg_conn).to receive(:respond_to?).with(:transaction_status).and_return(true)
        allow(pg_conn).to receive(:transaction_status).and_return(PG::PQTRANS_IDLE)
      end

      it 'detects idle and creates index CONCURRENTLY', :no_txn do
        allow(definition).to receive_messages(refresh_strategy: 'concurrent', unique_index_columns: %w[id])

        res = service.run

        expect(res).to be_success
        expect(mv_exists?(relname)).to be(true)
        expect(res.response[:created_indexes]).not_to be_nil

        expect(ar_conn).to have_received(:execute)
          .with(a_string_matching(/CREATE UNIQUE INDEX CONCURRENTLY/))
        expect(index_count_for(relname, "public_#{relname}_uniq_id%")).to eq(1)
      end
    end

    context 'when inside a transaction (non-idle)' do
      before do
        allow(pg_conn).to receive(:respond_to?).with(:transaction_status).and_return(true)
        allow(pg_conn).to receive(:transaction_status).and_return(PG::PQTRANS_INTRANS)
      end

      it 'detects non-idle and creates index without CONCURRENTLY' do
        allow(definition).to receive_messages(refresh_strategy: 'concurrent', unique_index_columns: %w[id])

        res = service.run

        expect(res).to be_success
        expect(mv_exists?(relname)).to be(true)
        expect(res.response[:created_indexes]).not_to be_nil

        expect(ar_conn).to have_received(:execute)
          .with(a_string_matching(/\ACREATE UNIQUE INDEX(?!.*CONCURRENTLY)/))
        expect(index_count_for(relname, "public_#{relname}_uniq_id%")).to eq(1)
      end
    end

    context 'when raw connection does not expose transaction_status' do
      before do
        allow(pg_conn).to receive(:respond_to?).with(:transaction_status).and_return(false)
      end

      it 'assumes idle and creates index CONCURRENTLY', :no_txn do
        allow(definition).to receive_messages(refresh_strategy: 'concurrent', unique_index_columns: %w[id])

        res = service.run

        expect(res).to be_success
        expect(mv_exists?(relname)).to be(true)
        expect(res.response[:created_indexes]).not_to be_nil

        expect(ar_conn).to have_received(:execute)
          .with(a_string_matching(/CREATE UNIQUE INDEX CONCURRENTLY/))
        expect(index_count_for(relname, "public_#{relname}_uniq_id%")).to eq(1)
      end
    end

    context 'when raw_connection raises (rescue path)' do
      before do
        allow(ar_conn).to receive(:raw_connection).and_raise(StandardError, 'boom')
      end

      it 'rescues and assumes non-idle (no CONCURRENTLY)' do
        allow(definition).to receive_messages(refresh_strategy: 'concurrent', unique_index_columns: %w[id])

        res = service.run

        expect(res).to be_success
        expect(mv_exists?(relname)).to be(true)
        expect(res.response[:created_indexes]).not_to be_nil

        expect(ar_conn).to have_received(:execute)
          .with(a_string_matching(/\ACREATE UNIQUE INDEX(?!.*CONCURRENTLY)/))
        expect(index_count_for(relname, "public_#{relname}_uniq_id%")).to eq(1)
      end
    end

    context 'when transaction_status call raises (rescue path)' do
      before do
        allow(pg_conn).to receive(:respond_to?).with(:transaction_status).and_return(true)
        allow(pg_conn).to receive(:transaction_status).and_raise(StandardError, 'oops')
      end

      it 'rescues and assumes non-idle (no CONCURRENTLY)' do
        allow(definition).to receive_messages(refresh_strategy: 'concurrent', unique_index_columns: %w[id])

        res = service.run

        expect(res).to be_success
        expect(mv_exists?(relname)).to be(true)
        expect(res.response[:created_indexes]).not_to be_nil

        expect(ar_conn).to have_received(:execute)
          .with(a_string_matching(/\ACREATE UNIQUE INDEX(?!.*CONCURRENTLY)/))
        expect(index_count_for(relname, "public_#{relname}_uniq_id%")).to eq(1)
      end
    end
  end

  describe 'unexpected DB error' do
    it 'wraps exception into error response' do
      allow(ActiveRecord::Base).to receive(:connection).and_wrap_original do |m, *args|
        c = m.call(*args)
        allow(c).to receive(:execute).and_raise(StandardError, 'boom')
        c
      end
      res = execute_service

      expect(res).not_to be_success
      expect(res.error?).to be(true)
      expect(res.error[:message]).to match(/boom/)
      expect(res.error[:class]).to eq('StandardError')
      expect(res.error[:backtrace]).to be_an(Array)
    end
  end
end
