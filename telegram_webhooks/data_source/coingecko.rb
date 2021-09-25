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
        vs_currencies
      end
      # rubocop:enable Lint/UnusedMethodArgument

      def fetch_prices(ids:, quote:)
        sparklines = {}

        # NOTE: /coins/markets endpoint always returns sparkline in USD
        # so in order to get more accurate data we should call /coins/{id}/market_chart for any non-USD pair
        if quote != 'USD'
          ids.each do |id|
            sparklines[id] = sparkline(id: id, quote: quote)
          end
        end

        res = RestClient.get(
          'https://api.coingecko.com/api/v3/coins/markets',
          {
            params: { vs_currency: quote, ids: ids.join(','), order: 'market_cap_desc', sparkline: true }
          }
        )

        JSON.parse(res.body).map do |item|
          item['sparkline_in_7d']['price'] = sparklines[item['id']] if sparklines.key?(item['id'])
          item.merge('quote' => quote)
        end
      end

      def fetch_batch_prices(id:, quotes:)
        sparklines = {}
        # TODO: Refactor with threads
        quotes.each do |quote|
          sparklines[quote] = sparkline(id: id, quote: quote)
        end

        res = RestClient.get(
          "https://api.coingecko.com/api/v3/coins/#{id}",
          {
            params: {
              sparkline: true,
              localization: false,
              developer_data: false,
              community_data: false,
              tickers: false
            }
          }
        )

        res = JSON.parse(res.body)
        items = quotes.map { |quote| build_cache_item(res, quote, sparklines[quote]) }

        cache_prices(items)
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

      private

      def build_cache_item(res, quote, sparkline)
        {
          'current_price' => res['market_data']['current_price'][quote.downcase],
          'quote' => quote,
          'name' => res['name'],
          'symbol' => res['symbol'].upcase,
          'id' => res['id'],
          'image' => res['image']['large'],
          'sparkline_in_7d' => sparkline ? { 'price' => sparkline } : res['market_data']['sparkline_7d'],
          'price_change_percentage_24h' => res['market_data']['price_change_percentage_24h_in_currency'][quote.downcase]
        }
      end

      def sparkline(id:, quote:)
        res = RestClient.get(
          "https://api.coingecko.com/api/v3/coins/#{id}/market_chart",
          params: { vs_currency: quote, days: 7, interval: 'hourly' }
        )

        JSON.parse(res.body)['prices'].map { |item| item[1] }
      end
    end
  end
end
