# frozen_string_literal: true

module Handler
  class InlineQuery < Base
    attr_reader :chat_type, :id

    def initialize(query)
      super

      @chat_type = query['chat_type']
      @id = query['id']
      @query = query['query']
    end

    def method_name
      'answerInlineQuery'
    end

    def params
      result = {
        inline_query_id: id,
        results: build_inline_query_answer,
        is_personal: true,
        cache_time: 0
      }

      return result if %w[private sender].include?(chat_type) || user.registered?

      result.merge(switch_pm_parameter: '0', switch_pm_text: 'How it works?')
    end

    private

    def build_inline_query_answer
      selected = Searcher.call(query: query)

      return [] if selected.empty?

      selected_ids = selected.keys
      prices = DataSource::CoinGecko.prices(ids: selected_ids, quote: 'USD')

      result = prices.map { |symbol| render_inline_query_item(symbol) }

      result.to_json
    end

    def render_inline_query_item(symbol)
      price = Money.from_amount(symbol['current_price'], 'USD').format
      title = "#{symbol['name']} (#{symbol['symbol'].upcase})"
      initial_state = CallbackData.new(base: symbol['id'], source: 'coingecko', quote: 'USD')

      {
        type: :article,
        id: "#{symbol['id']}:coingecko:USD",
        title: title,
        description: "#{price} @ CoinGecko",
        thumb_url: symbol['image'],
        thumb_width: 250,
        thumb_height: 250,
        input_message_content: {
          message_text: "#{title} — #{price}"
        },
        reply_markup: build_reply_markup(state: initial_state, try_button: !%w[private sender].include?(chat_type))
      }
    end
  end
end
