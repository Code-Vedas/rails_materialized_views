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

  before do
    conn.execute(%(DROP MATERIALIZED VIEW IF EXISTS public."#{relname}" CASCADE))
    conn.execute(%(DROP VIEW IF EXISTS public."#{relname}_dep" CASCADE))
  end

  it 'deletes an existing matview (RESTRICT default) when no deps' do
    create_mv!(relname)
    expect(mv_exists?(relname)).to be(true)

    res = described_class.new(definition).run

    expect(res).to be_success
    expect(res.status).to eq(:deleted)
    expect(res.payload[:view]).to eq(qualified)
    expect(res.meta[:sql]).to eq(%(DROP MATERIALIZED VIEW IF EXISTS "public"."#{relname}" RESTRICT))
    expect(mv_exists?(relname)).to be(false)
  end

  it 'skips when not present and if_exists=true' do
    expect(mv_exists?(relname)).to be(false)

    res = described_class.new(definition, if_exists: true).run

    expect(res).to be_success
    expect(res.status).to eq(:skipped)
    expect(res.payload[:view]).to eq(qualified)
    expect(res.meta[:sql]).to be_nil
  end

  it 'deletes when exists and if_exists=false' do
    create_mv!(relname)
    expect(mv_exists?(relname)).to be(true)

    res = described_class.new(definition, if_exists: false).run

    expect(res).to be_success
    expect(res.status).to eq(:deleted)
    expect(res.payload[:view]).to eq(qualified)
    expect(res.meta[:sql]).to eq(%(DROP MATERIALIZED VIEW IF EXISTS "public"."#{relname}" RESTRICT))
    expect(mv_exists?(relname)).to be(false)
  end

  it 'errors when not present and if_exists=false' do
    res = described_class.new(definition, if_exists: false).run

    expect(res.error?).to be(true)
    expect(res.error).to match(/does not exist/i)
  end

  it 'errors with helpful message when dependencies exist and cascade=false', :no_txn do
    create_mv!(relname)
    # Create a dependent plain view
    conn.execute(%(CREATE VIEW public."#{relname}_dep" AS SELECT * FROM public."#{relname}"))

    res = described_class.new(definition, cascade: false).run

    expect(res.error?).to be(true)
    expect(res.error).to match(/dependencies exist/i)
    expect(mv_exists?(relname)).to be(true) # still there
  end

  it 'drops with cascade=true even if dependencies exist' do
    create_mv!(relname)
    conn.execute(%(CREATE VIEW public."#{relname}_dep" AS SELECT * FROM public."#{relname}"))

    res = described_class.new(definition, cascade: true).run

    expect(res).to be_success
    expect(res.status).to eq(:deleted)
    expect(mv_exists?(relname)).to be(false)
  end

  it 'fails fast on invalid name format' do
    definition.name = 'public.bad' # contains a dot
    res = described_class.new(definition).run

    expect(res.error?).to be(true)
    expect(res.error).to match(/Invalid view name format/i)
  end

  context 'when statandard error is raised' do
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
      res = described_class.new(definition).run

      expect(res.error?).to be(true)
      expect(res.error).to eq('StandardError: boom')
      expect(res.meta[:backtrace]).to be_present
      expect(res.payload[:view]).to eq(qualified)
    end
  end
end
