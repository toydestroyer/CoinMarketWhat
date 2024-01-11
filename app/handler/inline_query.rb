# frozen_string_literal: true

module Handler
  class InlineQuery < Base
    attr_reader :chat_type, :id, :query

    def initialize(payload)
      super

      # NOTE: If chat_type is absent then the query is most likely from a secret chat or third-party client,
      # either way, we'll treat it as secret. I.e. no buttons and stuff.
      # https://core.telegram.org/bots/api#inlinequery
      @chat_type = payload['chat_type'] || 'secret'
      @id = payload['id']
      @query = payload['query']
    end

    def method_name
      'answerInlineQuery'
    end

    def params
      inline_query_results = InlineQueryResultsCollection.new(query:, chat_type:, user:)
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
