# frozen_string_literal: true

RSpec.describe CallbackData do
  subject(:result) { described_class.new(**params) }

  let(:base) { 'bitcoin' }
  let(:source) { 'coingecko' }
  let(:source_offset) { 0 }
  let(:quote) { 'USD' }
  let(:quote_offset) { 0 }

  let(:params) do
    {
      base:,
      source:,
      source_offset:,
      quote:,
      quote_offset:
    }
  end

  it 'have string representation' do
    expect(result.to_s).to eq('bitcoin:coingecko[0]:USD[0]')
  end

  context 'when data length is too long' do
    let(:base) { 'non-existing-coin-with-super-long-awesome-name' }

    it 'raises an error' do
      expect { result.to_s }.to raise_error(RuntimeError, 'data length exceed 64 chars')
    end
  end

  describe '#parse' do
    subject(:result) { described_class.parse(data) }

    let(:data) { 'bitcoin:coingecko[0]:USD[0]' }
    let(:expected_attributes) do
      { base: 'bitcoin', source: 'coingecko', source_offset: 0, quote: 'USD', quote_offset: 0 }
    end

    it { is_expected.to have_attributes(expected_attributes) }
    it { is_expected.to be_an_instance_of(described_class) }

    context 'when data length is too long' do
      let(:data) { 'non-existing-coin-with-super-long-awesome-name:binance[0]:USDT[0]' }

      it 'raises an error' do
        expect { result }.to raise_error(RuntimeError, 'data length exceed 64 chars')
      end
    end

    context "when data doesn't match expected pattern" do
      let(:data) { 'bitcoin[0]:coingecko[0]:USD[0]' }

      it 'raises an error' do
        expect { result }.to raise_error(RuntimeError, "data doesn't match expected pattern")
      end
    end
  end
end
