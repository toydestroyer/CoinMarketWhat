# frozen_string_literal: true

module Handler
  class CallbackQuery < Base
    attr_reader :chat_instance, :state, :price

    def initialize(query)
      super

      @chat_instance = BigDecimal(query['chat_instance'])
      @state = CallbackData.parse(query['data'])
      @price = render_price(amount: symbol['current_price'], quote: state.quote)
      enqueue_answer_callback_query
    end

    def method_name
      'editMessageText'
    end

    def params
      {
        text: "#{title} — #{price}",
        inline_message_id: query['inline_message_id'],
        reply_markup: build_reply_markup(state: state, try_button: chat_instance.negative?).to_json
      }
    end

    private

    def enqueue_answer_callback_query
      Lambda.sqs.send_message(
        queue_url: ENV['CALLBACK_QUERIES_QUEUE'],
        message_body: query.to_json
      )
    end

    def symbol
      @symbol ||= begin
        data_source = DATA_SOURCES_MAP[state.source]
        data_source.prices(ids: [state.base], quote: state.quote)[0]
      end
    end

    def title
      "#{symbol['name']} (#{symbol['symbol'].upcase})"
    end

    def render_price(amount:, quote:)
      Money.from_amount(amount, quote).format
    rescue Money::Currency::UnknownCurrency => _e
      "#{amount} #{quote}"
    end
  end
end
