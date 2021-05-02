module DataSource
  class Binance < Base
    class << self
      def name
        'Binance'
      end

      def prices(tickers:)
        res = RestClient.get('https://api.binance.com/api/v3/ticker/price')

        # Because Binance API doesn't allow to get prices for multiple tickers. Either one or all.
        all_prices = JSON.parse(res.body)

        all_prices.select { |price| tickers.include?(price['symbol']) }
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
