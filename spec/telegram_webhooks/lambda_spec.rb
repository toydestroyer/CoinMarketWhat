# frozen_string_literal: true

RSpec.describe Lambda do
  describe 'Webhooks' do
    let(:event) do
      {
        'body' => '{}'
      }
    end

    it 'works' do
      expect { described_class.webhook(event: event, context: {}) }.to raise_error
    end
  end
end
