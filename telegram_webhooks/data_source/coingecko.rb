# frozen_string_literal: true

module DataSource
  class CoinGecko < Base
    class << self
      def name
        'CoinGecko'
      end

      # For CoinGecko id is not in use because list of pairs is static
      # Full list of supported pairs here https://api.coingecko.com/api/v3/simple/supported_vs_currencies
      # rubocop:disable Lint/UnusedMethodArgument
      def pairs(id:)
        %w[USD EUR CNY JPY KRW]
      end
      # rubocop:enable Lint/UnusedMethodArgument

      def prices(ids:, quote: 'USD')
        valid_prices = fetch_cached_prices(ids: ids, quote: quote)

        return render_cached_prices(valid_prices) if valid_prices.size == ids.size

        res = RestClient.get(
          'https://api.coingecko.com/api/v3/coins/markets',
          {
            params: {
              vs_currency: quote,
              ids: ids.join(','),
              order: 'market_cap_desc'
            }
          }
        )

        result = JSON.parse(res.body)

        update = result.map do |item|
          {
            put_request: {
              item: {
                resource_id: "#{item['id']}:#{slug}:#{quote}",
                resource_type: 'price',
                price: item['current_price'],
                name: item['name'],
                symbol: item['symbol'],
                id: item['id'],
                image: item['image'],
                valid_to: Time.now.to_i + 60
              }
            }
          }
        end

        Lambda.dynamodb.batch_write_item(
          request_items: {
            'CoinMarketWhatDB' => update
          }
        )

        result
      end

      def load_assets
        JSON.parse(Lambda.s3.get_object(bucket: ENV['CACHE_BUCKET'], key: "#{slug}.json").body.read)
      end

      def cache_assets
        result = []
        page = 1

        loop do
          res = RestClient.get(
            'https://api.coingecko.com/api/v3/coins/markets',
            {
              params: {
                vs_currency: 'USD',
                # Sorting by market cap breaks the pagination and produces duplicates with missing assets,
                # Therefore sorting by id is more reliable
                order: 'id_asc',
                per_page: '250',
                page: page
              }
            }
          )

          body = JSON.parse(res.body)

          break if body.empty?

          result += body.map do |item|
            {
              id: item['id'],
              symbol: item['symbol'],
              name: item['name'],
              image: item['image'],
              rank: item['market_cap_rank']
            }
          end

          page += 1
        end

        # Nulls last
        result = result.sort_by { |i| i[:rank] || 100_000 }

        Lambda.s3.put_object(
          key: "#{slug}.json",
          body: result.to_json,
          bucket: ENV['CACHE_BUCKET'],
          storage_class: 'ONEZONE_IA',
          metadata: {
            count: result.size.to_s,
            updated_at: Time.now.to_s
          }
        )
      end

      private

      def fetch_cached_prices(ids:, quote:)
        keys = ids.map { |id| { resource_id: [id, slug, quote].join(':'), resource_type: 'price' } }
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

      def render_cached_prices(prices)
        prices.map do |price|
          {
            'current_price' => price['price'].to_f,
            'name' => price['name'],
            'symbol' => price['symbol'],
            'id' => price['id'],
            'image' => price['image'],
          }
        end
      end
    end
  end
end
