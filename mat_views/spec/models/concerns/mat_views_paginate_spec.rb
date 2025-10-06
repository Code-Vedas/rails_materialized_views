# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViewsPaginate do
  let(:test_model) { MatViews::MatViewDefinition }
  let!(:definitions) { create_list(:mat_view_definition, 10) }

  describe '.paginate' do
    it 'paginates correctly for valid page and per_page' do
      page1 = test_model.paginate(total: 10, page: 1, per_page: 3)
      expect(page1.size).to eq(3)
      expect(page1.first.name).to eq(definitions.first.name)

      page2 = test_model.paginate(total: 10, page: 2, per_page: 3)
      expect(page2.size).to eq(3)
      expect(page2.first.name).to eq(definitions[3].name)

      page4 = test_model.paginate(total: 10, page: 4, per_page: 3)
      expect(page4.size).to eq(1)
      expect(page4.first.name).to eq(definitions[9].name)
    end

    it 'defaults per_page to 20 if invalid' do
      page1 = test_model.paginate(total: 10, page: 1, per_page: 0)
      expect(page1.size).to eq(10)
    end

    it 'adjusts page if out of bounds' do
      page_neg = test_model.paginate(total: 10, page: -1, per_page: 3)
      expect(page_neg.size).to eq(3)
      expect(page_neg.first.name).to eq(definitions.first.name)

      page_too_high = test_model.paginate(total: 10, page: 5, per_page: 3)
      expect(page_too_high.size).to eq(3)
      expect(page_too_high.first.name).to eq(definitions.first.name)
    end
  end
end
