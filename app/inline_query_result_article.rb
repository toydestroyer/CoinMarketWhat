# frozen_string_literal: true

class InlineQueryResultArticle
  attr_reader :id, :symbol, :chat_type, :user, :price, :title, :state

  def initialize(symbol:, chat_type:, user:)
    @id = SecureRandom.uuid
    @symbol = symbol
    @chat_type = chat_type
    @user = user
    @price = Money.from_amount(symbol['current_price'], 'USD').format
    @title = "#{symbol['name']} (#{symbol['symbol'].upcase})"
    @state = CallbackData.new(base: symbol['id'], source: 'coingecko', quote: 'USD')
  end

  def render
    {
      type: :article,
      id:,
      title:,
      description: "#{price} @ CoinGecko",
      thumb_url: symbol['image'],
      thumb_width: 250,
      thumb_height: 250,
      input_message_content: {
        message_text: "#{title} — #{price}"
      },
      reply_markup: ReplyMarkup.new(state:).render
    }
  end
end
