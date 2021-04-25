require 'json'
require 'aws-sdk-dynamodb'
require 'aws-sdk-ssm'
require 'rest-client'

require_relative './data_source/base'
require_relative './data_source/binance'

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
  current_state = decompose_callback_data(query['data'])

  current_ticker = binance.available_assets.select { |item| item[:base] == current_state[:base] && item[:quote] == current_state[:quote] }[0][:ticker]

  prices = binance.prices(tickers: [current_ticker])
  price = prices.select { |item| item['symbol'] == current_ticker }[0]['price']
  title = "#{current_state[:base]}/#{current_state[:quote]}"

  avaliable_pairs = binance.available_assets.select { |item| item[:base] == current_state[:base] }

  add_nav = false

  if avaliable_pairs.size > 4
    avaliable_pairs = avaliable_pairs[current_state[:quote_offset], 3]
    add_nav = true
  end

  pairs = avaliable_pairs.map do |item|
    { text: item[:quote] == current_state[:quote] ? "• #{item[:quote]} •" : item[:quote], callback_data: "#{current_state[:base]}[#{current_state[:base_offset]}]:binance[0]:#{item[:quote]}[#{current_state[:quote_offset]}]" }
  end

  pairs << { text: '→', callback_data: "#{current_state[:base]}[#{current_state[:base_offset]}]:binance[0]:#{current_state[:quote]}[#{current_state[:quote_offset] + 1}]" } if add_nav


  RestClient.get("https://api.telegram.org/bot#{token}/editMessageText", params: {
    text: "#{title} — #{price}",
    inline_message_id: query['inline_message_id'],
    reply_markup: {
      inline_keyboard: [
        [
          { text: '• Binance •', callback_data: "#{current_state[:base]}[#{current_state[:base_offset]}]:binance[#{current_state[:source_offset]}]:#{current_state[:quote]}[#{current_state[:quote_offset]}]" }
        ],
        pairs
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
  selected = if query.empty?
    binance.available_assets.first(10)
  else
    binance.available_assets.select { |item| item[:ticker].include?(query.upcase) }.first(10)
  end

  selected_tickers = selected.map { |item| item[:ticker] }
  prices = binance.prices(tickers: selected_tickers)

  result = selected.map do |symbol|
    price = prices.select { |item| item['symbol'] == symbol[:ticker] }[0]['price']
    title = "#{symbol[:base]}/#{symbol[:quote]}"

    avaliable_pairs = binance.available_assets.select { |item| item[:base] == symbol[:base] }

    add_nav = false

    if avaliable_pairs.size > 4
      avaliable_pairs = avaliable_pairs.first(3)
      add_nav = true
    end

    pairs = avaliable_pairs.map do |item|
      { text: item[:quote] == symbol[:quote] ? "• #{item[:quote]} •" : item[:quote], callback_data: "#{symbol[:base]}[0]:binance[0]:#{item[:quote]}[0]" }
    end

    pairs << { text: '→', callback_data: "null" } if add_nav

    {
      type: :article,
      id: SecureRandom.hex,
      title: title,
      thumb_url: "https://dummyimage.com/512x512/ffffff/000000.png&text=#{title}",
      input_message_content: {
        message_text: "#{title} — #{price}"
      },
      reply_markup: {
        inline_keyboard: [
          [
            { text: '• Binance •', callback_data: "#{symbol[:base]}[0]:binance[0]:#{symbol[:quote]}[0]" }
          ],
          pairs
        ]
      }
    }
  end

  result.to_json
end

def decompose_callback_data(data)
  result = data.split(/^(\w+?)\[(\d+)\]:(\w+?)\[(\d+)\]:(\w+?)\[(\d+)\]$/).drop(1)

  {
    base: result[0],
    base_offset: result[1].to_i,
    source: result[2],
    source_offset: result[3].to_i,
    quote: result[4],
    quote_offset: result[5].to_i
  }
end

def build_reply_markup

end

def binance
  @binance ||= DataSource::Binance.new
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

def dynamodb
  @dynamodb ||= Aws::DynamoDB::Client.new(region: 'eu-north-1')
end

def ssm
  @ssm ||= Aws::SSM::Client.new(region: 'eu-north-1')
end

def token
  @token ||= ssm.get_parameter(name: '/bots/telegram/CoinMarketWhat').parameter.value
end
