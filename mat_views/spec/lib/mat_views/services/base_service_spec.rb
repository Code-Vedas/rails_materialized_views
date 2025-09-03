# frozen_string_literal: true

RSpec.describe MatViews::Services::BaseService do
  let(:conn) { ActiveRecord::Base.connection }
  let(:relname) { 'mv_base_service_spec' }
  let(:qualified) { "public.#{relname}" }
  let(:definition) do
    build(:mat_view_definition,
          name: relname,
          sql: 'SELECT id FROM users',
          refresh_strategy: :swap,
          unique_index_columns: [])
  end
  let(:row_count_strategy) { :estimated }
  let(:runner_class) do
    ## A simple subclass to test the abstract base class.
    Class.new(described_class) do
      private

      def _run
        @response = { view: "#{schema}.#{rel}" }
        ok(:ok)
      end

      def assign_request
        @request = { row_count_strategy: row_count_strategy }
      end

      def prepare
        nil
      end
    end
  end
  let(:runner) { runner_class.new(definition, row_count_strategy:) }
  let(:execute_service) { runner.run }

  describe 'abstract methods' do
    context 'when _run is not implemented' do
      let(:bad_runner_class) do
        Class.new(described_class) do
          private

          def prepare; end

          def assign_request; end
        end
      end

      it 'raises NotImplementedError' do
        expect { bad_runner_class.new(definition).run }.to raise_error(NotImplementedError, /Must implement.*_run/)
      end
    end

    context 'when assign_request is not implemented' do
      let(:bad_runner_class) do
        Class.new(described_class) do
          private

          def prepare; end

          def _run; end
        end
      end

      it 'raises NotImplementedError' do
        expect { bad_runner_class.new(definition).run }.to raise_error(NotImplementedError, /Must implement.*assign_request/)
      end
    end

    context 'when prepare is not implemented' do
      let(:bad_runner_class) do
        Class.new(described_class) do
          private

          def _run; end

          def assign_request; end
        end
      end

      it 'raises NotImplementedError' do
        expect { bad_runner_class.new(definition).run }.to raise_error(NotImplementedError, /Must implement.*prepare/)
      end
    end
  end

  describe 'schema_search_path resolution' do
    it 'falls back to public when search_path is empty' do
      allow(conn).to receive(:schema_search_path).and_return('')
      res = execute_service
      expect(res).to be_success
      expect(res.response[:view]).to eq("public.#{relname}")
    end

    it 'ignores non-existent schemas and falls back to public' do
      allow(conn).to receive(:schema_search_path).and_return('other_schema')
      res = execute_service
      expect(res).to be_success
      expect(res.response[:view]).to eq("public.#{relname}")
    end

    it 'handles quoted tokens' do
      allow(conn).to receive(:schema_search_path).and_return('"public"')
      res = execute_service
      expect(res).to be_success
      expect(res.response[:view]).to eq("public.#{relname}")
    end

    it 'handles $user token; uses public when user schema is absent' do
      allow(conn).to receive(:schema_search_path).and_return('$user,public')
      res = execute_service
      expect(res).to be_success
      expect(res.response[:view]).to eq("public.#{relname}")
    end
  end
end
