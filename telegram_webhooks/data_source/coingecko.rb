module DataSource
  class CoinGecko < Base
    class << self
      def prices(ids:)
        res = RestClient.get(
          'https://api.coingecko.com/api/v3/coins/markets',
          {
            params: {
              vs_currency: 'USD',
              ids: ids.join(','),
              order: 'market_cap_desc'
            }
          }
        )

        JSON.parse(res.body)
      end

      def load_assets
        result = []
        # page = 1

        # loop do
          res = RestClient.get(
            'https://api.coingecko.com/api/v3/coins/markets',
            {
              params: {
                vs_currency: 'USD',
                order: 'market_cap_desc',
                per_page: '250',
                # page: page
              }
            }
          )

          body = JSON.parse(res.body)

          # break if body.empty?

          result = result + body.map do |item|
            {
              id: item['id'],
              symbol: item['symbol'],
              name: item['name'],
              image: item['image'],
              rank: item['market_cap_rank']
            }
          end

          # page += 1
        # end

        result
      end
    end
  end
end
