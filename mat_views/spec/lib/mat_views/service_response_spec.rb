# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MatViews::ServiceResponse do
  describe '#initialize' do
    it 'sets attributes with defaults' do
      res = described_class.new(status: :ok)

      expect(res.status).to eq(:ok)
      expect(res.payload).to eq({})
      expect(res.error).to be_nil
      expect(res.meta).to eq({})
    end

    it 'symbolizes status when given a string' do
      res = described_class.new(status: 'created')
      expect(res.status).to eq(:created)
    end

    it 'accepts custom values' do
      err = StandardError.new('boom')
      res = described_class.new(
        status: :updated,
        payload: { rows: 10 },
        error: err,
        meta: { attempt: 2 }
      )

      expect(res.payload).to eq(rows: 10)
      expect(res.error).to eq(err)
      expect(res.meta).to eq(attempt: 2)
    end
  end

  describe '#success?' do
    %i[ok created updated noop].each do |ok_status|
      it "is true for #{ok_status} when there is no error" do
        res = described_class.new(status: ok_status)
        expect(res.success?).to be true
      end
    end

    it 'is false when error is present even if status is ok-ish' do
      res = described_class.new(status: :ok, error: StandardError.new('x'))
      expect(res.success?).to be false
    end

    it 'is false for non-ok statuses' do
      res = described_class.new(status: :pending)
      expect(res.success?).to be false
    end
  end

  describe '#error?' do
    it 'is true when error object is present' do
      res = described_class.new(status: :ok, error: RuntimeError.new('nope'))
      expect(res.error?).to be true
    end

    it 'is true when status is :error even without error object' do
      res = described_class.new(status: :error)
      expect(res.error?).to be true
    end

    it 'is false when no error and status is not :error' do
      res = described_class.new(status: :ok)
      expect(res.error?).to be false
    end
  end

  describe '#to_h' do
    it 'returns a full hash representation' do
      err = RuntimeError.new('kaput')
      res = described_class.new(
        status: :noop,
        payload: { count: 1 },
        error: err,
        meta: { source: 'spec' }
      )

      expect(res.to_h).to eq(
        status: :noop,
        payload: { count: 1 },
        error: err,
        meta: { source: 'spec' }
      )
    end
  end
end
