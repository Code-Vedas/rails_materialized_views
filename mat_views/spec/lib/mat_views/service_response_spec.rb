# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::ServiceResponse do
  describe '#initialize' do
    it 'sets attributes with defaults' do
      res = described_class.new(status: :ok)

      expect(res.status).to eq(:ok)
      expect(res.request).to eq({})
      expect(res.response).to eq({})
      expect(res.error).to be_nil
    end

    it 'symbolizes status when given a string' do
      res = described_class.new(status: 'created')
      expect(res.status).to eq(:created)
    end

    it 'accepts custom values' do
      err = StandardError.new('boom')
      res = described_class.new(
        status: :updated,
        request: { rows: 10 },
        error: err,
        response: { attempt: 2 }
      )

      expect(res.request).to eq(rows: 10)
      expect(res.error[:message]).to eq('boom')
      expect(res.error[:class]).to eq('StandardError')
      expect(res.error[:backtrace]).to be_an(Array)
      expect(res.status).to eq(:updated)
      expect(res.response).to eq(attempt: 2)
    end

    it 'raise ArgumentError if status is nil' do
      expect { described_class.new(status: nil) }.to raise_error(ArgumentError, /status is required/)
    end

    it 'raise ArgumentError if error is not an Exception' do
      expect { described_class.new(status: :error, error: 'nope') }
        .to raise_error(ArgumentError, /error must be Exception object/)
    end
  end

  describe '#success?' do
    %i[ok created updated skipped deleted].each do |ok_status|
      it "is true for #{ok_status} when there is no error" do
        res = described_class.new(status: ok_status)
        expect(res).to be_success
      end
    end

    it 'is false for non-ok statuses' do
      res = described_class.new(status: :error)

      expect(res).not_to be_success
    end
  end

  describe '#error?' do
    it 'is false when status is not :error' do
      res = described_class.new(status: :ok)
      expect(res.error?).to be false
    end
  end

  describe '#to_h' do
    it 'returns a full hash representation' do
      err = RuntimeError.new('kaput')
      res = described_class.new(
        status: :skipped,
        request: { count: 1 },
        error: err,
        response: { source: 'spec' }
      )

      expect(res.to_h).to eq(
        status: :skipped,
        request: { count: 1 },
        error: {
          message: 'kaput',
          class: 'RuntimeError',
          backtrace: []
        },
        response: { source: 'spec' }
      )
    end
  end
end
