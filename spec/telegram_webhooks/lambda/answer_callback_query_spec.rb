# frozen_string_literal: true

RSpec.describe Lambda::AnswerCallbackQuery, :with_lambda do
  let(:event) { { 'Records' => [record] } }
  let(:callback_query) { json_fixture('telegram/callback_query.json') }
  let(:record) { { 'Sns' => { 'Message' => body } } }
  let(:body) { callback_query.to_json }
  let(:stub_url) { "https://api.telegram.org/bot#{ENV['TELEGRAM_BOT_API_TOKEN']}/answerCallbackQuery" }

  before do
    success = file_fixture('telegram/successful_response.json')

    stub_request(:post, stub_url).to_return(status: 200, body: success)
  end

  it 'works' do
    result

    expect(a_request(:post, stub_url)).to have_been_made.once
  end
end
