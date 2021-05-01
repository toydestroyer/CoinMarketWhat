module DataSource
  class CoinMarketCap < Base
    attr_reader :api_key

    def initialize(api_key:)
      @api_key = api_key
    end

    def prices(ids:)
      res = RestClient.get(
        'https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest',
        {
          params: {
            id: ids.join(','),
            # I don't need all these additional data, but it's not possible to exclude it completely,
            # so I'm just sticking with smallest field
            aux: 'cmc_rank'
          },
          'X-CMC_PRO_API_KEY' => api_key
        }
      )

      JSON.parse(res.body)['data']
    end

    def load_assets
      res = RestClient.get(
        'https://pro-api.coinmarketcap.com/v1/cryptocurrency/map',{
          params: {
            sort: 'cmc_rank'
          },
          'X-CMC_PRO_API_KEY' => api_key
        }
      )

      data = JSON.parse(res.body)['data']

      data.map do |item|
        {
          id: item['id'],
          name: item['name'],
          symbol: item['symbol'],
          slug: item['slug'],
          cmc_rank: item['rank']
        }
      end
    end
  end
end
