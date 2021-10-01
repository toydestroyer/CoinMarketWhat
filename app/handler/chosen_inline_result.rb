# frozen_string_literal: true

module Handler
  class ChosenInlineResult < Base
    attr_reader :inline_message_id, :result_id

    def initialize(query)
      super

      Lambda.dynamodb.put_item(
        table_name: ENV['DYNAMODB_TABLE_NAME'],
        item: inline_query_result.merge(
          resource_type: 'telegram/inline_message',
          resource_id: query['inline_message_id'],
          user_id: user.id,
          created_at: Time.current.to_i,
          updated_at: Time.current.to_i
        )
      )
    end

    def respond; end

    def process; end

    private

    def inline_query_result
      result = Lambda.dynamodb.get_item(
        table_name: ENV['DYNAMODB_TABLE_NAME'],
        key: { resource_type: 'telegram/inline_query_result', resource_id: query['result_id'] }
      ).item

      return {} unless result

      result.slice('chat_type', 'type', 'state')
    end
  end
end
