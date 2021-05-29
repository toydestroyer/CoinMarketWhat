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

        render_prices(body: JSON.parse(res.body), id: id, asset: asset)
      end

      def render_prices(body:, id:, asset:)
        price = body['price'].to_f

        [
          {
            'id' => id,
            'symbol' => asset['symbol'],
            'name' => asset['name'],
            'current_price' => price
          }
        ]
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
    end
  end
end
