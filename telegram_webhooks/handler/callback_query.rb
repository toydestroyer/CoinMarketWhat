# frozen_string_literal: true

module Handler
  class CallbackQuery < Base
    def handle
      current_state = decompose_callback_data(query['data'])
      data_source = Lambda.data_sources_map[current_state[:source]]

      symbol = data_source.prices(ids: [current_state[:base]], quote: current_state[:quote])[0]
      price = render_price(amount: symbol['current_price'], quote: current_state[:quote])

      edit_message(symbol: symbol, price: price, state: current_state)
    end

    def render_price(amount:, quote:)
      Money.from_amount(amount, quote).format
    rescue Money::Currency::UnknownCurrency => _e
      "#{amount} #{quote}"
    end

    def edit_message(symbol:, price:, state:)
      title = "#{symbol['name']} (#{symbol['symbol'].upcase})"

      RestClient.get(
        "https://api.telegram.org/bot#{token}/editMessageText",
        params: {
          text: "#{title} — #{price}",
          inline_message_id: query['inline_message_id'],
          reply_markup: build_reply_markup(state).to_json
        }
      )
    end
  end
end
