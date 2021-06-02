# frozen_string_literal: true

module Command
  class Base
    attr_reader :command, :user, :chat, :token

    def initialize(command:, user:, chat:)
      @command = command
      @user = user
      @chat = chat
      @token = ENV['TELEGRAM_BOT_API_TOKEN']
    end

    def message
      {}
    end

    def method_name
      'sendMessage'
    end

    def process
      params = message.merge(chat_id: chat['id'])

      RestClient.get("https://api.telegram.org/bot#{token}/#{method_name}", params: params)
    end
  end
end
