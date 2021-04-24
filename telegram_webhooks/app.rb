require 'json'
require 'aws-sdk-dynamodb'
require 'aws-sdk-ssm'
require 'rest-client'

def lambda_handler(event:, context:)
  log_request(event)
  body = JSON.parse(event['body'])
  render_inline(body['inline_query']) if body.key?('inline_query')
  handle_callback(body['callback_query']) if body.key?('callback_query')

  {
    statusCode: 200,
    body: 'ok'
  }
end

def handle_callback(query)
  RestClient.get("https://api.telegram.org/bot#{token}/editMessageText", params: {
    text: SecureRandom.uuid,
    inline_message_id: query['inline_message_id'],
    reply_markup: {
      inline_keyboard: [
        [
          { text: 'Binance', callback_data: 'binance' },
          { text: 'Bitfinex', callback_data: 'bitfinex' },
          { text: 'CoinMarketCap', callback_data: 'coinmarketcap' },
        ],
        [
          { text: 'USDT', callback_data: 'usdt' },
          { text: 'BTC', callback_data: 'btc' },
          { text: 'ETH', callback_data: 'eth' }
        ]
      ]
    }.to_json
  })
end

def render_inline(query)
  RestClient.get("https://api.telegram.org/bot#{token}/answerInlineQuery", params: {
    inline_query_id: query['id'],
    results: build_inline_query_answer(query: query['query']),
    cache_time: 0
  })
rescue => e
  puts e.to_json
end

def build_inline_query_answer(query:)
  prices = get_binance_prices

  puts prices

  selected = if query.empty?
    prices.select { |item| ['BTCUSDT', 'ETHUSDT', 'BNBUSDT'].include?(item['symbol']) }
  else
    prices.select { |item| item['symbol'].include?(query.upcase) }.first(10)
  end

  puts selected

  result = selected.map do |symbol|
    {
      type: :article,
      id: SecureRandom.hex,
      title: "#{symbol['symbol']} — #{symbol['price']}",
      thumb_url: "https://dummyimage.com/512x512/ffffff/000000.png&text=#{symbol['symbol']}",
      input_message_content: {
        message_text: "#{symbol['symbol']} — #{symbol['price']}"
      },
      reply_markup: {
        inline_keyboard: [
          [
            { text: 'Binance', callback_data: 'binance' },
            { text: 'Bitfinex', callback_data: 'bitfinex' },
            { text: 'CoinMarketCap', callback_data: 'coinmarketcap' },
          ],
          [
            { text: 'USDT', callback_data: 'usdt' },
            { text: 'BTC', callback_data: 'btc' },
            { text: 'ETH', callback_data: 'eth' }
          ]
        ]
      }
    }
  end

  puts result

  result.to_json
end

def log_request(event)
  puts event.to_json
  puts event['body'].to_json

  dynamodb.put_item(
    table_name: 'CoinMarketWhatDB',
    item: {
      'resource_id' => SecureRandom.uuid,
      'resource_type' => 'telegram_log',
      'query' => event['body'],
      'created_at' => Time.now.to_s
    }
  )
end

def get_binance_prices
  JSON.parse(RestClient.get('https://api.binance.com/api/v3/ticker/price').body)
end

def dynamodb
  @dynamodb ||= Aws::DynamoDB::Client.new(region: 'eu-north-1')
end

def ssm
  @ssm ||= Aws::SSM::Client.new(region: 'eu-north-1')
end

def token
  @token ||= ssm.get_parameter(name: '/bots/telegram/CoinMarketWhat').parameter.value
end
