# frozen_string_literal: true

module Handler
  class InlineQuery < Base
    attr_reader :chat_type, :id

    def initialize(query)
      super

      @chat_type = query['chat_type'] || 'secret'
      @id = query['id']
      @query = query['query']
    end

    def method_name
      'answerInlineQuery'
    end

    def params
      inline_query_results = InlineQueryResultsCollection.new(query: query, chat_type: chat_type, user: user)
      result = {
        inline_query_id: id,
        results: inline_query_results.to_json,
        is_personal: true,
        cache_time: 60
      }

      result = result.merge(switch_pm_parameter: '0', switch_pm_text: 'How it works?') if user.unregistered?

      result
    end
  end
end
