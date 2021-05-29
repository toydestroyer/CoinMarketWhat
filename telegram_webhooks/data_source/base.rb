# frozen_string_literal: true

module DataSource
  class Base
    class << self
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

      def prices(ids:, quote:)
        valid_prices = fetch_cached_prices(ids: ids, quote: quote)
        return render_cached_prices(valid_prices) if valid_prices.size == ids.size

        latest_prices = fetch_prices(ids: ids, quote: quote)
        cache_prices(prices: latest_prices, quote: quote)

        latest_prices
      end

      private

      def fetch_cached_prices(ids:, quote:)
        keys = ids.map { |id| { resource_id: price_id(id: id, quote: quote), resource_type: 'price' } }
        resp = Lambda.dynamodb.batch_get_item(
          request_items: {
            'CoinMarketWhatDB' => {
              keys: keys
            }
          }
        )

        # TODO: Find a way to filter it out in dyanmo directly
        resp.responses['CoinMarketWhatDB'].select { |item| Time.now.to_i < item['valid_to'].to_i }
      end

      def cache_prices(prices:, quote:)
        update = prices.map do |item|
          {
            put_request: {
              item: build_put_request_item(item: item, quote: quote)
            }
          }
        end

        Lambda.dynamodb.batch_write_item(
          request_items: { 'CoinMarketWhatDB' => update }
        )
      end

      def render_cached_prices(prices)
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

      def price_id(id:, quote:)
        [id, slug, quote].join(':')
      end

      def build_put_request_item(item:, quote:)
        {
          resource_id: price_id(id: item['id'], quote: quote),
          resource_type: 'price',
          price: item['current_price'],
          name: item['name'],
          symbol: item['symbol'],
          id: item['id'],
          image: item['image'],
          valid_to: Time.now.to_i + 60
        }
      end
    end
  end
end
