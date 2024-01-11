# frozen_string_literal: true

module Command
  class Base
    attr_reader :command, :user, :chat

    def initialize(command:, user:, chat:)
      @command = command
      @user = user
      @chat = chat
    end

    def message
      {}
    end

    def method_name
      'sendMessage'
    end

    def process
      params = message.merge(chat_id: chat['id'])

      puts RestClient.post("https://api.telegram.org/bot#{ENV.fetch('TELEGRAM_BOT_API_TOKEN')}/#{method_name}", params)
    end
  end
end
