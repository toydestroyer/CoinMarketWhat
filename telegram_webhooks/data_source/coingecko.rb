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
        # rubocop:enable Lint/UnusedMethodArgument
        %w[USD EUR CNY JPY KRW]
      end

      def prices(ids:, quote: 'USD')
        keys = ids.map { |id| { resource_id: ['coingecko', id, quote].join(':'), resource_type: 'price' } }
        resp = dynamodb.batch_get_item(
          request_items: {
            'CoinMarketWhatDB' => {
              keys: keys
            }
          }
        )

        puts resp

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
                updated_at: Time.now.to_i
              }
            }
          }
        end

        resp = dynamodb.batch_write_item(
          request_items: {
            'CoinMarketWhatDB' => update
          }
        )

        puts resp

        result
      end

      def load_assets
        JSON.parse(s3.get_object(bucket: ENV['CACHE_BUCKET'], key: "#{slug}.json").body.read)
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

        s3.put_object(
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
    end
  end
end
