# frozen_string_literal: true

module Handler
  class Base
    attr_reader :query, :user

    def initialize(query)
      @query = query
      @user = Telegram::User.new(query['from'])
    end

    def process
      puts RestClient.post("https://api.telegram.org/bot#{ENV['TELEGRAM_BOT_API_TOKEN']}/#{method_name}", params)
    end

    def respond
      params.merge(method: method_name)
    end

    def method_name
      raise 'not implemented'
    end

    def params
      {}
    end
  end
end
