require 'json'
require 'aws-sdk-dynamodb'
require 'aws-sdk-sqs'
require 'aws-sdk-ssm'
require 'rest-client'

require_relative './data_source/base'
require_relative './data_source/binance'

def lambda_handler(event:, context:)
  body = JSON.parse(event['body'])
  log_request(body, event['requestContext']['accountId'])

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

  RestClient.get("https://api.telegram.org/bot#{token}/editMessageText", params: {
    text: "#{title} — #{price}",
    inline_message_id: query['inline_message_id'],
    reply_markup: build_reply_markup(current_state).to_json
  })
end

def render_inline(query)
  RestClient.get("https://api.telegram.org/bot#{token}/answerInlineQuery", params: {
    inline_query_id: query['id'],
    results: build_inline_query_answer(query: query['query']),
    cache_time: 0
  })
rescue RestClient::ExceptionWithResponse => e
  puts e.response.to_json
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

    initial_state = decompose_callback_data("#{symbol[:base]}[0]:binance[0]:#{symbol[:quote]}[0]")

    {
      type: :article,
      id: SecureRandom.hex,
      title: "#{title}",
      description: "#{price} @ Binance",
      thumb_url: "https://dummyimage.com/512x512/ffffff/000000.png&text=#{title}",
      input_message_content: {
        message_text: "#{title} — #{price}"
      },
      reply_markup: build_reply_markup(initial_state)
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

def build_reply_markup(state)
  avaliable_pairs = binance.available_assets.select { |item| item[:base] == state[:base] }

  pagination = false

  # Due to display concerns, I want to limit the number of buttons in the row to 4
  # If available pairs more than 4 then only 3 will be displayed along with the pagination arrow
  if avaliable_pairs.size > 4
    avaliable_pairs = avaliable_pairs[state[:quote_offset], 3]
    pagination = true
  end

  pairs = avaliable_pairs.map do |item|
    { text: item[:quote] == state[:quote] ? "• #{item[:quote]} •" : item[:quote], callback_data: "#{state[:base]}[#{state[:base_offset]}]:#{state[:source]}[#{state[:source_offset]}]:#{item[:quote]}[#{state[:quote_offset]}]" }
  end

  pairs << { text: '→', callback_data: "#{state[:base]}[#{state[:base_offset]}]:#{state[:source]}[#{state[:source_offset]}]:#{state[:quote]}[#{state[:quote_offset] + 1}]" } if pagination

  {
    inline_keyboard: [
      [
        { text: '• Binance •', callback_data: "#{state[:base]}[#{state[:base_offset]}]:#{state[:source]}[#{state[:source_offset]}]:#{state[:quote]}[#{state[:quote_offset]}]" }
      ],
      pairs
    ]
  }
end

def binance
  @binance ||= DataSource::Binance.new
end

def log_request(event, account_id)
  sqs.send_message(
    queue_url: "https://sqs.eu-north-1.amazonaws.com/#{account_id}/CoinMarketWhatLogsQueue",
    message_body: event.to_json
  )
end

def dynamodb
  @dynamodb ||= Aws::DynamoDB::Client.new(region: 'eu-north-1')
end

def sqs
  @sqs ||= Aws::SQS::Client.new(region: 'eu-north-1')
end

def ssm
  @ssm ||= Aws::SSM::Client.new(region: 'eu-north-1')
end

def token
  @token ||= ssm.get_parameter(name: '/bots/telegram/CoinMarketWhat').parameter.value
end
