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

        expect(RequestLogger).to have_received(:enqueue).with({ random: 'param' }.to_json)
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

  describe '#logger' do
    subject(:result) { described_class.logger(event: event, context: nil) }

    let(:event) { { 'Records' => records } }
    let(:records) { [{ 'body' => body, 'attributes' => { 'SentTimestamp' => '1621341605522' } }] }
    let(:body) { file_fixture('telegram/callback_query.json') }
    let(:s3) { described_class.s3 }

    it 'creates s3 object' do
      expect { result }.to change { s3.list_objects(bucket: ENV['LOGS_BUCKET']).contents.size }.from(0).to(1)
    end

    it 'saves object with correct key' do
      result

      object = s3.get_object(bucket: ENV['LOGS_BUCKET'], key: 'callback_query/year=2021/month=05/day=18/hour=12/1.json')
      expect(object).to be_any
    end
  end
end
