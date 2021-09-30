# frozen_string_literal: true

class Cacher
  attr_accessor :result

  EXCHANGES = ['binance'].freeze

  def initialize
    @result = {}
  end

  def call
    load_assets
    sort_assets

    EXCHANGES.each do |exchange|
      load_tickers(exchange: exchange)
    end

    save_to_s3
  end

  private

  def load_assets
    page = 1

    loop do
      res = fetch_markets_data(page: page)
      body = JSON.parse(res.body)
      break if body.empty?

      body.each { |item| populate_result(item) }

      page += 1
    end
  end

  def load_tickers(exchange:)
    page = 1

    loop do
      res = RestClient.get("https://api.coingecko.com/api/v3/exchanges/#{exchange}/tickers", { params: { page: page } })
      tickers = JSON.parse(res.body)['tickers']

      break if tickers.empty?

      tickers.each { |item| populate_tickers(item: item, exchange: exchange) }

      page += 1
    end
  end

  def populate_result(item)
    result[item['id']] = {
      symbol: item['symbol'].upcase,
      name: item['name'],
      image: item['image'],
      rank: item['market_cap_rank'],
      tickers: {
        coingecko: { symbol: item['symbol'].upcase, quotes: nil }
      }
    }
  end

  def populate_tickers(item:, exchange:)
    result[item['coin_id']][:tickers][exchange] ||= { symbol: item['base'], quotes: [] }
    result[item['coin_id']][:tickers][exchange][:quotes] << item['target']
  end

  # Sorting by market cap breaks the pagination and produces duplicates with missing assets,
  # Therefore sorting by id is more reliable
  def fetch_markets_data(page:, per_page: 250, order: 'id_asc', quote: 'USD')
    RestClient.get(
      'https://api.coingecko.com/api/v3/coins/markets',
      {
        params: {
          vs_currency: quote,
          order: order,
          per_page: per_page,
          page: page
        }
      }
    )
  end

  def sort_assets
    @result = result.sort_by { |_k, v| v[:rank] || Float::INFINITY }.to_h
  end

  def save_to_s3
    Lambda.s3.put_object(
      key: 'coingecko.json',
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
