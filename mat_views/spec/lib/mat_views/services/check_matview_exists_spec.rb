# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::Services::CheckMatviewExists do
  let(:conn)     { ActiveRecord::Base.connection }
  let(:relname)  { 'mv_check_exists_spec' }
  let(:qualified) { "public.#{relname}" }

  let(:definition) do
    build(:mat_view_definition,
          name: relname,
          sql: 'SELECT id FROM users',
          refresh_strategy: :concurrent,
          unique_index_columns: %w[id])
  end

  let(:runner)          { described_class.new(definition) }
  let(:execute_service) { runner.call }

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

  describe '#call' do
    it 'returns exists: false when the view does not exist' do
      res = execute_service
      expect(res).to be_success
      expect(res.response).to eq({ exists: false })
      expect(mv_exists?(relname)).to be(false)
    end

    it 'returns exists: true when the view exists' do
      create_mv!(relname)
      expect(mv_exists?(relname)).to be(true)

      res = execute_service
      expect(res).to be_success
      expect(res.response).to eq({ exists: true })
      expect(mv_exists?(relname)).to be(true)
    end
  end
end
