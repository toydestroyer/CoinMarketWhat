# frozen_string_literal: true

module Handler
  class InlineQuery < Base
    def handle
      RestClient.get("https://api.telegram.org/bot#{token}/answerInlineQuery", params: {
                       inline_query_id: query['id'],
                       results: build_inline_query_answer(query: query['query']),
                       cache_time: 0
                     })
    end
  end
end
