# frozen_string_literal: true
module DataSource
  class CoinGecko < Base
    class << self
      def name
        'CoinGecko'
      end

      # For CoinGecko id is not in use because list of pairs is static
      # Full list of supported pairs here https://api.coingecko.com/api/v3/simple/supported_vs_currencies
      def pairs(id:)
        ['USD', 'EUR', 'CNY', 'JPY', 'KRW']
      end

      def prices(ids:, quote: 'USD')
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

        JSON.parse(res.body)
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

          result = result + body.map do |item|
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
