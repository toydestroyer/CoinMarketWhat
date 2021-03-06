# frozen_string_literal: true

class InlineQueryResultsCollection
  def initialize(query:, chat_type:, user:)
    @results = []
    selected = Searcher.call(query: query)

    return if selected.empty?

    prices = DataSource::CoinGecko.prices(ids: selected.keys, quote: 'USD')

    prices.each do |symbol|
      results << InlineQueryResultArticle.new(symbol: symbol, chat_type: chat_type, user: user)
    end

    save!
  end

  def to_json(*args)
    JSON.generate(results.map(&:render), *args)
  end

  private

  attr_reader :results

  def save!
    results.each_slice(25) do |slice|
      batch_items = slice.map do |item|
        {
          put_request: {
            item: {
              resource_type: 'telegram/inline_query_result',
              resource_id: item.id,
              chat_type: item.chat_type,
              type: 'article',
              user_id: item.user.id,
              state: { base: item.symbol['id'], source: 'coingecko', quote: 'USD' },
              valid_to: 5.minutes.from_now.to_i
            }
          }
        }
      end

      Lambda.dynamodb.batch_write_item(request_items: { ENV['DYNAMODB_TABLE_NAME'] => batch_items })
    end
  end
end
