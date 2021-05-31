# frozen_string_literal: true

module Command
  class Start < Base
    def process
      register_user if command == '/start'

      super
    end

    def message
      {
        text: 'Hey!',
        reply_markup: {
          inline_keyboard: [
            {
              text: 'Try it out',
              switch_inline_query_current_chat: ''
            }
          ]
        }
      }
    end

    private

    def register_user
      item = from.merge(resource_type: 'TelegramUser', resource_id: from['id'].to_s, created_at: Time.now.to_i)

      Lambda.dynamodb.put_item(
        table_name: 'CoinMarketWhatDB',
        item: item
      )
    end
  end
end
