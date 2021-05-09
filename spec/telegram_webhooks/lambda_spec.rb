# frozen_string_literal: true

RSpec.describe Lambda do
  describe 'Webhooks' do
    let(:event) do
      {
        'body' => '{}'
      }
    end

    xit 'works' do
      expect { described_class.webhook(event: event, context: {}) }.not_to raise_error
    end
  end

  it 'does not work' do
    expect(1).to eq(2)
  end
end
