# frozen_string_literal: true

RSpec.describe Lambda::Webhook, :with_lambda do
  before do
    allow(EventLog).to receive(:enqueue)
    allow(Handler::InlineQuery).to receive(:new)
    allow(Handler::CallbackQuery).to receive(:new)
    allow(Sentry).to receive(:capture_exception)
  end

  context 'with any event' do
    let(:body) { { random: 'param' } }

    it { is_expected.to include(statusCode: 200, body: '') }

    it 'not raise an error' do
      expect { result }.not_to raise_error
    end

    it 'sends log to queue' do
      result

      expect(EventLog).to have_received(:enqueue).with({ random: 'param' }.to_json, event_name: 'random')
    end

    it "doesn't captures any exceptions" do
      result

      expect(Sentry).not_to have_received(:capture_exception)
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

  context 'when something wrong' do
    let(:body) { { callback_query: { some: :thing } } }

    context 'with any error' do
      before do
        allow(Handler::CallbackQuery).to receive(:new).and_raise('something')
      end

      it 'captures the exception' do
        result

        expect(Sentry).to have_received(:capture_exception).with(RuntimeError)
      end
    end
  end
end
