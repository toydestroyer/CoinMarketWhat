# frozen_string_literal: true

RSpec.describe Searcher do
  subject(:op_result) { described_class.call(query:) }

  context 'with empty query' do
    let(:query) { '' }

    it 'returns top results' do
      expect(op_result.keys).to contain_exactly('bitcoin', 'ethereum', 'bitcoin-cash')
    end
  end

  context 'with exact match by symbol' do
    let(:query) { 'BTC' }

    it 'returns proper results' do
      expect(op_result.keys).to contain_exactly('bitcoin')
    end
  end

  context 'with partial match by symbol' do
    let(:query) { 'B' }

    it 'returns proper results' do
      expect(op_result.keys).to contain_exactly('bitcoin', 'bitcoin-cash')
    end
  end

  context 'with exact match by name' do
    let(:query) { 'ethereum' }

    it 'returns proper results' do
      expect(op_result.keys).to contain_exactly('ethereum')
    end
  end

  context 'with partial match by name' do
    let(:query) { 'ether' }

    it 'returns proper results' do
      expect(op_result.keys).to contain_exactly('ethereum')
    end
  end

  context 'with mixed match by name' do
    let(:query) { 'bitcoin' }

    it 'returns proper results' do
      expect(op_result.keys).to contain_exactly('bitcoin', 'bitcoin-cash')
    end
  end
end
