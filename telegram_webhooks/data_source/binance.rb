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
        symbol = "#{asset['symbol']}#{quote}"
        res = RestClient.get(
          'https://api.binance.com/api/v3/ticker/24hr',
          {
            params: { symbol: symbol }
          }
        )

        item = JSON.parse(res.body)

        ct = Time.now
        klines_start_time = (Time.new(ct.year, ct.month, ct.day, ct.hour) - 604_800).to_i * 1000
        klines_params = { symbol: symbol, interval: '1h', startTime: klines_start_time}
        res = RestClient.get('https://api.binance.com/api/v3/klines', params: klines_params)
        item['sparkline'] = JSON.parse(res).map { |kline| kline[2].to_f }

        render_prices(body: item, id: id, asset: asset, quote: quote)
      end

      def render_prices(body:, id:, asset:, quote:)
        [
          {
            'id' => id,
            'symbol' => asset['symbol'],
            'quote' => quote,
            'name' => asset['name'],
            'image' => asset['image'],
            'current_price' => body['lastPrice'].to_f,
            'sparkline_in_7d' => {
              'price' => body['sparkline']
            },
            'price_change_percentage_24h' => body['priceChangePercent'].to_f
          }
        ]
      end

      def fetch_batch_prices(id:, quotes:)
        asset = CoinGecko.available_assets[id]
        symbol = asset['symbol']
        symbols = quotes.map { |quote| "#{symbol}#{quote}" }

        result = []
        # TODO: Threads
        symbols.each do |symbol|
          res = RestClient.get('https://api.binance.com/api/v3/ticker/24hr', params: { symbol: symbol })
          item = JSON.parse(res)

          ct = Time.now
          klines_start_time = (Time.new(ct.year, ct.month, ct.day, ct.hour) - 604_800).to_i * 1000
          klines_params = { symbol: symbol, interval: '1h', startTime: klines_start_time}
          res = RestClient.get('https://api.binance.com/api/v3/klines', params: klines_params)
          item['sparkline'] = JSON.parse(res).map { |kline| kline[2].to_f }
          result << item
        end

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
            'current_price' => item['lastPrice'].to_f,
            'quote' => item['symbol'][asset['symbol'].size...],
            'name' => asset['name'],
            'symbol' => asset['symbol'],
            'id' => id,
            'image' => asset['image'],
            'sparkline_in_7d' => {
              'price' => item['sparkline']
            },
            'price_change_percentage_24h' => item['priceChangePercent'].to_f
          }
        end
      end
    end
  end
end
