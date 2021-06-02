# frozen_string_literal: true

module Lambda
  class AnswerCallbackQuery < Base
    def process
      token = ENV['TELEGRAM_BOT_API_TOKEN']
      puts "Records: #{event['Records'].size}"

      event['Records'].each do |record|
        record = JSON.parse(record['body'])

        puts RestClient.post("https://api.telegram.org/bot#{token}/answerCallbackQuery", callback_query_id: record['id'])
      end
    end
  end
end