# frozen_string_literal: true

module DataSource
  class CoinGecko < Base
    class << self
      def display_name
        'CoinGecko'
      end

      # For CoinGecko id is not in use because list of pairs is static
      # Full list of supported pairs here https://api.coingecko.com/api/v3/simple/supported_vs_currencies
      # rubocop:disable Lint/UnusedMethodArgument
      def pairs(id:, matching: nil)
        vs_currencies
      end
      # rubocop:enable Lint/UnusedMethodArgument

      def fetch_prices(ids:, quote:)
        res = RestClient.get(
          'https://api.coingecko.com/api/v3/coins/markets',
          {
            params: { vs_currency: quote, ids: ids.join(','), order: 'market_cap_desc' }
          }
        )

        JSON.parse(res.body)
      end

      def fetch_batch_prices(id:, quotes:)
        asset = available_assets[id]

        res = RestClient.get('https://api.coingecko.com/api/v3/simple/price', { params: { ids: id, vs_currencies: quotes.join(',') } })
        result = JSON.parse(res)[id]

        items = result.map do |quote, price|
          {
            put_request: {
              item: {
                resource_id: [id, slug, quote.upcase].join(':'),
                resource_type: 'price',
                price: price,
                name: asset['name'],
                symbol: asset['symbol'],
                id: asset['id'],
                image: asset['image'],
                valid_to: Time.now.to_i + 60
              }
            }
          }
        end

        Lambda.dynamodb.batch_write_item(
          request_items: { 'CoinMarketWhatDB' => items }
        )
      end

      def load_assets
        JSON.parse(Lambda.s3.get_object(bucket: ENV['CACHE_BUCKET'], key: "#{slug}.json").body.read)
      end

      def vs_currencies
        @vs_currencies ||= begin
          res = RestClient.get('https://api.coingecko.com/api/v3/simple/supported_vs_currencies')
          result = JSON.parse(res.body)
          money_by_priority = Money::Currency.map { |e| e.id.to_s }
          result = result.sort_by { |e| money_by_priority.index(e) || Float::INFINITY }

          result.map(&:upcase)
        end
      end
    end
  end
end
