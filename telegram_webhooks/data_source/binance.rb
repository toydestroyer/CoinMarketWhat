# frozen_string_literal: true

module DataSource
  class Binance < Base
    class << self
      def display_name
        'Binance'
      end

      def fetch_prices(ids:, quote:)
        id = ids.first
        asset = CoinGecko.available_assets[id]
        res = RestClient.get(
          'https://api.binance.com/api/v3/ticker/price',
          {
            params: { symbol: "#{asset['symbol']}#{quote}" }
          }
        )

        render_prices(body: JSON.parse(res.body), id: id, asset: asset, quote: quote)
      end

      def render_prices(body:, id:, asset:, quote:)
        price = body['price'].to_f

        [
          {
            'id' => id,
            'symbol' => asset['symbol'],
            'quote' => quote,
            'name' => asset['name'],
            'current_price' => price,
            'sparkline_in_7d' => {
              'price' => []
            }
          }
        ]
      end

      def fetch_batch_prices(id:, quotes:)
        asset = CoinGecko.available_assets[id]
        symbol = asset['symbol']
        symbols = quotes.map { |quote| "#{symbol}#{quote}" }

        res = RestClient.get('https://api.binance.com/api/v3/ticker/price')
        result = JSON.parse(res)
        result = result.select { |item| symbols.include?(item['symbol']) }

        items = build_price_items(result: result, id: id, asset: asset)

        cache_prices(items)
      end

      def load_assets
        res = RestClient.get('https://api.binance.com/api/v3/exchangeInfo')
        symbols = JSON.parse(res.body)['symbols']

        symbols.map do |symbol|
          {
            base: symbol['baseAsset'],
            quote: symbol['quoteAsset'],
            ticker: symbol['symbol']
          }
        end
      end

      private

      def build_price_items(result:, id:, asset:)
        result.map do |item|
          {
            'current_price' => item['price'].to_f,
            'quote' => item['symbol'][asset['symbol'].size...],
            'name' => asset['name'],
            'symbol' => asset['symbol'],
            'id' => id,
            'image' => asset['image'],
            'sparkline_in_7d' => {
              'price' => []
            }
          }
        end
      end
    end
  end
end
