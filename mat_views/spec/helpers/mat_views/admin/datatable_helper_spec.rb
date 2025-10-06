# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::Admin::DatatableHelper, type: :helper do
  let(:rel) { MatViews::MatViewDefinition }

  describe '#dt_apply_sort' do
    let(:columns) do
      {
        name: { sort: :name },
        strategy: { sort: :refresh_strategy }
      }
    end

    before do
      allow(rel).to receive_messages(ordered_by_name: rel, ordered_by_refresh_strategy: rel)
    end

    it 'applies ascending sort by default' do
      helper.params[:dtsort] = 'name:asc'
      helper.send(:dt_apply_sort, rel, columns)
      expect(rel).to have_received(:ordered_by_name).with(:asc)
    end

    it 'applies descending sort when specified' do
      helper.params[:dtsort] = 'strategy:desc'
      helper.send(:dt_apply_sort, rel, columns)
      expect(rel).to have_received(:ordered_by_refresh_strategy).with(:desc)
    end

    it 'sorts by ascending when direction is absent' do
      helper.params[:dtsort] = 'strategy'
      helper.send(:dt_apply_sort, rel, columns)
      expect(rel).to have_received(:ordered_by_refresh_strategy).with(:asc)
    end

    it 'ignores unknown columns' do
      helper.params[:dtsort] = 'invalid:desc'
      expect { helper.send(:dt_apply_sort, rel, columns) }.not_to raise_error
    end

    it 'returns relation unchanged when dtsort is blank' do
      expect(helper.send(:dt_apply_sort, rel, columns)).to eq(rel)
    end
  end

  describe '#dt_apply_search' do
    let(:columns) do
      {
        name: { search: :name },
        strategy: { search: :refresh_strategy }
      }
    end

    before do
      allow(rel).to receive_messages(search_by_name: rel, search_by_refresh_strategy: rel, or: rel)
    end

    it 'applies all searchable columns using OR logic' do
      helper.params[:dtsearch] = 'materialized'
      helper.send(:dt_apply_search, rel, columns)
      expect(rel).to have_received(:search_by_name).with('materialized')
      expect(rel).to have_received(:search_by_refresh_strategy).with('materialized')
      expect(rel).to have_received(:or).at_least(:once)
    end

    it 'returns rel when dtsearch is missing' do
      expect(helper.send(:dt_apply_search, rel, columns)).to eq(rel)
    end
  end

  describe '#dt_apply_filter' do
    let(:columns) do
      {
        status: { filter: :status },
        strategy: { filter: :refresh_strategy }
      }
    end

    before do
      allow(rel).to receive_messages(filtered_by_refresh_strategy: rel)
    end

    it 'applies multiple filters' do
      helper.params[:dtfilter] = 'status:active,strategy:regular'
      helper.send(:dt_apply_filter, rel, columns)
      expect(rel).to have_received(:filtered_by_refresh_strategy).with('regular')
    end

    it 'returns rel when dtfilter is absent' do
      expect(helper.send(:dt_apply_filter, rel, columns)).to eq(rel)
    end
  end

  describe '#dt_apply_pagination' do
    before do
      allow(rel).to receive_messages(count: 100, paginate: rel, total_pages: 5)
    end

    it 'calculates pagination attributes and paginates' do
      helper.params[:dtpage] = '2'
      helper.params[:dtperpage] = '25'

      result = helper.send(:dt_apply_pagination, rel, 10)
      expect(result).to eq(rel)
      expect(helper.instance_variable_get(:@dt_page)).to eq(2)
      expect(helper.instance_variable_get(:@dt_per_page)).to eq(25)
      expect(helper.instance_variable_get(:@dt_total_pages)).to eq(5)
      expect(rel).to have_received(:paginate).with(total: 100, page: 2, per_page: 25)
    end

    it 'uses default per_page when missing' do
      result = helper.send(:dt_apply_pagination, rel, 15)
      expect(helper.instance_variable_get(:@dt_per_page)).to eq(15)
      expect(result).to eq(rel)
    end
  end

  describe '#pagination_window' do
    it 'returns full window with gaps correctly' do
      result = helper.send(:pagination_window, current_page: 6, total_pages: 20)
      expect(result).to eq([1, :gap, 4, 5, 6, 7, 8, :gap, 20])
    end

    it 'handles small total_pages without gaps' do
      result = helper.send(:pagination_window, current_page: 2, total_pages: 3)
      expect(result).to eq([1, 1, 2, 3, 3].uniq) # dedup edge overlap
    end

    it 'returns empty array when total_pages < 1' do
      expect(helper.send(:pagination_window, current_page: 1, total_pages: 0)).to eq([])
    end
  end

  describe '#parse_headers_to_params' do
    before do
      allow(helper.request).to receive(:headers).and_return({
                                                              'X-Dtsearch' => 'users',
                                                              'X-Dtsort' => 'name:asc',
                                                              'X-Dtfilter' => 'status:active',
                                                              'X-DtPage' => '2',
                                                              'X-DtPerPage' => '25'
                                                            })
    end

    it 'parses headers into params' do
      helper.send(:parse_headers_to_params)
      expect(helper.params[:dtsearch]).to eq('users')
      expect(helper.params[:dtsort]).to eq('name:asc')
      expect(helper.params[:dtfilter]).to eq('status:active')
      expect(helper.params[:dtpage]).to eq('2')
      expect(helper.params[:dtperpage]).to eq('25')
    end

    it 'does not overwrite existing params' do
      helper.params[:dtsort] = 'custom:desc'
      helper.send(:parse_headers_to_params)
      expect(helper.params[:dtsort]).to eq('custom:desc')
    end
  end

  context 'when no dtsearch is provided' do
    let(:columns) do
      {
        name: { search: :name },
        strategy: { search: :refresh_strategy }
      }
    end

    it 'returns rel as is' do
      expect(helper.send(:dt_apply_search, rel, columns)).to eq(rel)
    end
  end

  context 'when dtsearch is provided but no valid search columns' do
    it 'returns rel as is' do
      helper.params[:dtsearch] = 'materialized'
      expect(helper.send(:dt_apply_search, rel, {})).to eq(rel)
    end
  end

  context 'when no dtfilter is provided' do
    let(:columns) do
      {
        status: { filter: :status },
        strategy: { filter: :refresh_strategy }
      }
    end

    it 'returns rel as is' do
      expect(helper.send(:dt_apply_filter, rel, columns)).to eq(rel)
    end
  end

  context 'when dtfilter is provided but no valid filter columns' do
    it 'returns rel as is' do
      helper.params[:dtfilter] = 'status:active'
      expect(helper.send(:dt_apply_filter, rel, {})).to eq(rel)
    end
  end
end
