# frozen_string_literal: true

RSpec.describe Lambda do
  describe '#webhook' do
    subject(:result) { described_class.webhook(event: event, context: nil) }

    let(:event) { { 'body' => body.to_json } }

    before do
      allow(RequestLogger).to receive(:enqueue)
      allow(Handler::InlineQuery).to receive(:new)
      allow(Handler::CallbackQuery).to receive(:new)
    end

    context 'with any event' do
      let(:body) { { random: 'param' } }

      it 'not raise an error' do
        expect { result }.not_to raise_error
      end

      it 'returns 200 ok' do
        expect(result).to include(statusCode: 200, body: 'ok')
      end

      it 'sends log to queue' do
        result

        expect(RequestLogger).to have_received(:enqueue).with('random' => 'param')
      end
    end

    context 'with inline_query' do
      let(:body) { { inline_query: { some: :thing } } }

      it 'handles the event' do
        result

        expect(Handler::InlineQuery).to have_received(:new).with('some' => 'thing')
      end
    end

    context 'with callback_query' do
      let(:body) { { callback_query: { some: :thing } } }

      it 'handles the event' do
        result

        expect(Handler::CallbackQuery).to have_received(:new).with('some' => 'thing')
      end
    end
  end
end
