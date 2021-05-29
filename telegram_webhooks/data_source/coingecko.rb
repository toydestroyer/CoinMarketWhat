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
      def pairs(id:)
        %w[USD EUR CNY JPY KRW]
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

      def load_assets
        JSON.parse(Lambda.s3.get_object(bucket: ENV['CACHE_BUCKET'], key: "#{slug}.json").body.read)
      end
    end
  end
end
