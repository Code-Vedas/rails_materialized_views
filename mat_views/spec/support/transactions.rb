# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require 'pg'

RSpec.configure do |config|
  # Run each example in its own transaction that we always roll back…
  # …except those tagged :no_txn (needed for CONCURRENTLY), which run truly outside any tx.
  config.around do |example|
    conn = ActiveRecord::Base.connection

    if example.metadata[:no_txn]
      ensure_idle!(conn)        # no open/failed tx before
      example.run
      ensure_idle!(conn)        # and after
      drop_test_matviews!(conn) # tidy MVs created in these specs
    else
      # Use a new (non-joinable) tx and always roll it back so nothing persists or poisons the conn.
      conn.transaction(joinable: false, requires_new: true) do
        example.run
        raise ActiveRecord::Rollback
      end
      ensure_idle!(conn)
    end
  end
end

def ensure_idle!(conn = ActiveRecord::Base.connection)
  rc = conn.raw_connection
  case rc.transaction_status
  when PG::PQTRANS_INTRANS, PG::PQTRANS_INERROR
    # Only rollback if PG says we're actually in a tx or failed tx.
    conn.execute('ROLLBACK')
    # PG::PQTRANS_IDLE, PG::PQTRANS_ACTIVE, PG::PQTRANS_UNKNOWN → do nothing
  end
rescue ActiveRecord::StatementInvalid
  # If AR thought we were fine but PG says aborted, one best-effort ROLLBACK
  begin
    conn.execute('ROLLBACK')
  rescue StandardError
    nil
  end
end

def drop_test_matviews!(conn = ActiveRecord::Base.connection)
  %w[
    mv_create_service_spec
    mv_index_already_exists
    mv_concurrent_spec
    mv_runner_job_spec
  ].each do |rel|
    conn.execute(%(DROP MATERIALIZED VIEW IF EXISTS public."#{rel}"))
  end
end
