# frozen_string_literal: true

module Command
  class Base
    attr_reader :command, :from, :chat, :token

    def initialize(command:, from:, chat:)
      @command = command
      @from = from
      @chat = chat
      @token = ENV['TELEGRAM_BOT_API_TOKEN']
    end

    def message
      {}
    end

    def process
      params = message.merge(chat_id: chat['id'])

      RestClient.get("https://api.telegram.org/bot#{token}/sendMessage", params: params)
    end
  end
end
