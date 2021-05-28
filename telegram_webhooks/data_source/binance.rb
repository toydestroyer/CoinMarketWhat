# frozen_string_literal: true

module DataSource
  class Binance < Base
    class << self
      def display_name
        'Binance'
      end

      def prices(ids:, quote: 'USDT')
        asset = CoinGecko.available_assets[ids.first]
        res = RestClient.get('https://api.binance.com/api/v3/ticker/price', { params: { symbol: "#{asset['symbol']}#{quote}" } })

        price = JSON.parse(res.body)['price'].to_f

        [
          {
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
