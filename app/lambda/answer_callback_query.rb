# frozen_string_literal: true

module Lambda
  class AnswerCallbackQuery < Base
    IGNORED_DESCRIPTION = 'Bad Request: query is too old and response timeout expired or query ID is invalid'

    def process
      puts "Records: #{event['Records'].size}"

      event['Records'].each do |record|
        message = JSON.parse(record['Sns']['Message'])
        answer_callback_query(message['callback_query']['id'])
      end
    end

    private

    def answer_callback_query(id)
      puts RestClient.post(
        "https://api.telegram.org/bot#{ENV['TELEGRAM_BOT_API_TOKEN']}/answerCallbackQuery",
        callback_query_id: id
      )
    rescue RestClient::ExceptionWithResponse => e
      return if JSON.parse(e.response.body)['description'] == IGNORED_DESCRIPTION

      raise e
    end
  end
end
