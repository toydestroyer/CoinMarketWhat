# frozen_string_literal: true

module DataSource
  class Base
    class << self
      USD_ALL = %w[USD USDT USDC BUSD TUSD].freeze

      def display_name
        raise 'not implemented'
      end

      def slug
        @slug ||= display_name.downcase
      end

      def available_assets
        @available_assets ||= load_assets
      end

      def pairs(id:)
        CoinGecko.available_assets[id]['tickers'][slug]['quotes']
      end

      def pair_offset(id:, quote:)
        pairs(id:).index(quote) || 0
      end

      def matching_pair(id:, matching:)
        result = pairs(id:)
        result.detect { |e| e == matching || (USD_ALL.include?(e) && USD_ALL.include?(matching)) } || result[0]
      end

      def prices(ids:, quote:)
        valid_prices = fetch_cached_prices(ids:, quote:)
        return render_cached_prices(valid_prices) if valid_prices.size == ids.size

        latest_prices = fetch_prices(ids:, quote:)
        cache_prices(latest_prices)

        latest_prices
      end

      private

      def fetch_cached_prices(ids:, quote:)
        keys = ids.map { |id| { resource_id: price_id(id:, quote:), resource_type: 'price' } }
        resp = Lambda.dynamodb.batch_get_item(
          request_items: {
            ENV['DYNAMODB_TABLE_NAME'] => {
              keys:
            }
          }
        )

        # TODO: Find a way to filter it out in dyanmo directly
        resp.responses[ENV['DYNAMODB_TABLE_NAME']].select { |item| Time.now.to_i < item['valid_to'].to_i }
      end

      def cache_prices(items)
        update = items.map do |item|
          {
            put_request: {
              item: build_put_request_item(item)
            }
          }
        end

        Lambda.dynamodb.batch_write_item(
          request_items: { ENV['DYNAMODB_TABLE_NAME'] => update }
        )
      end

      def render_cached_prices(prices)
        prices = prices.sort_by { |e| prioritized_ids.index(e['id']) || Float::INFINITY }

        prices.map do |price|
          {
            'current_price' => price['price'].to_f,
            'name' => price['name'],
            'symbol' => price['symbol'],
            'id' => price['id'],
            'image' => price['image']
          }
        end
      end

      def prioritized_ids
        @prioritized_ids ||= CoinGecko.available_assets.select { |_k, v| v['rank'] }.keys
      end

      def price_id(id:, quote:)
        [id, slug, quote].join(':')
      end

      def build_put_request_item(item)
        resource_id = price_id(id: item['id'], quote: item['quote'])

        {
          resource_id:,
          resource_type: 'price',
          price: item['current_price'],
          name: item['name'],
          symbol: item['symbol'],
          id: item['id'],
          image: item['image'],
          sparkline: item['sparkline_in_7d']['price'],
          price_change_percentage_24h: item['price_change_percentage_24h'],
          valid_to: Time.now.to_i + 60
        }
      end
    end
  end
end
