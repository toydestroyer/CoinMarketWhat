# frozen_string_literal: true

RSpec.describe Lambda do
  describe '#webhook' do
    subject(:result) { described_class.webhook(event: event, context: nil) }

    let(:event) { { 'body' => body.to_json } }

    context 'with any event' do
      let(:body) { { random: 'param' } }

      before do
        allow(RequestLogger).to receive(:enqueue)
      end

      it 'not raise an error' do
        expect { result }.not_to raise_error
      end

      it 'returns 200 ok' do
        expect(result).to include(statusCode: 200, body: 'ok')
      end

      it 'sends log to queue' do
        result

        expect(RequestLogger).to have_received(:enqueue).with({ 'random' => 'param' })
      end
    end
  end
end
