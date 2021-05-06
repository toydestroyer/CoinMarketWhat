# frozen_string_literal: true

require 'json'
require 'aws-sdk-dynamodb'
require 'aws-sdk-sqs'
require 'aws-sdk-s3'
require 'aws-sdk-ssm'
require 'rest-client'
require 'money'

require_relative './data_source/base'
require_relative './data_source/binance'
require_relative './data_source/coingecko'
require_relative './data_source/coinmarketcap'
require_relative './searcher'

I18n.enforce_available_locales = false
Money.default_infinite_precision = true

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
  data_source = data_sources_map[current_state[:source]]

  symbol = data_source.prices(ids: [current_state[:base]], quote: current_state[:quote])[0]
  price = Money.from_amount(symbol['current_price'], current_state[:quote]).format
  title = "#{symbol['name']} (#{symbol['symbol'].upcase})"

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
# rescue => e
#   puts e.to_json
end

def build_inline_query_answer(query:)
  selected = Searcher.call(query: query)

  return [] if selected.empty?

  selected_ids = selected.map { |item| item['id'] }
  prices = DataSource::CoinGecko.prices(ids: selected_ids)

  # puts selected
  puts prices

  result = prices.map do |symbol|
    puts symbol
    price = Money.from_amount(symbol['current_price'], 'USD').format

    title = "#{symbol['name']} (#{symbol['symbol'].upcase})"

    initial_state = decompose_callback_data("#{symbol['id']}[0]:coingecko[0]:USD[0]")

    {
      type: :article,
      id: SecureRandom.hex,
      title: title,
      description: "#{price} @ CoinGecko",
      thumb_url: symbol['image'],
      thumb_width: 250,
      thumb_height: 250,
      input_message_content: {
        message_text: "#{title} — #{price}"
      },
      reply_markup: build_reply_markup(initial_state)
    }
  end

  result.to_json
end

# def build_inline_query_answer(query:)
#   selected = if query.empty?
#     coinmarketcap.available_assets.first(10)
#   else
#     coinmarketcap.available_assets.select { |item| item[:symbol].downcase.start_with?(query.downcase) }.first(10)
#   end

#   selected_ids = selected.map { |item| item[:id] }
#   prices = coinmarketcap.prices(ids: selected_ids)

#   # puts selected
#   puts prices

#   result = selected.map do |symbol|
#     puts symbol
#     price = prices[symbol[:id].to_s]['quote']['USD']['price']
#     price = Money.from_amount(price, 'USD').format

#     initial_state = decompose_callback_data("#{symbol[:id]}[0]:coinmarketcap[0]:USD[0]")

#     {
#       type: :article,
#       id: SecureRandom.hex,
#       title: symbol[:symbol],
#       description: "#{price} @ CoinMarketCap",
#       thumb_url: "https://s2.coinmarketcap.com/static/img/coins/128x128/#{symbol[:id]}.png",
#       thumb_width: 128,
#       thumb_height: 128,
#       input_message_content: {
#         message_text: "#{symbol[:symbol]} — #{price}"
#       },
#       reply_markup: build_reply_markup(initial_state)
#     }
#   end

#   result.to_json
# end

# def build_inline_query_answer(query:)
#   selected = if query.empty?
#     binance.available_assets.first(10)
#   else
#     binance.available_assets.select { |item| item[:base].downcase.start_with?(query.downcase) }.first(10)
#   end

#   selected_tickers = selected.map { |item| item[:ticker] }
#   prices = binance.prices(tickers: selected_tickers)

#   result = selected.map do |symbol|
#     price = prices.select { |item| item['symbol'] == symbol[:ticker] }[0]['price']
#     title = "#{symbol[:base]}/#{symbol[:quote]}"

#     initial_state = decompose_callback_data("#{symbol[:base]}[0]:binance[0]:#{symbol[:quote]}[0]")

#     {
#       type: :article,
#       id: SecureRandom.hex,
#       title: "#{title}",
#       description: "#{price} @ Binance",
#       thumb_url: "https://dummyimage.com/512x512/ffffff/000000.png&text=#{title}",
#       input_message_content: {
#         message_text: "#{title} — #{price}"
#       },
#       reply_markup: build_reply_markup(initial_state)
#     }
#   end

#   result.to_json
# end

def decompose_callback_data(data)
  result = data.split(/^([\w-]+?)\[(\d+)\]:(\w+?)\[(\d+)\]:(\w+?)\[(\d+)\]$/).drop(1)

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
  data_source = data_sources_map[state[:source]]
  avaliable_pairs = data_source.pairs(id: state[:base])

  pagination = false

  # Due to display concerns, I want to limit the number of buttons in the row to 4
  # If available pairs more than 4 then only 3 will be displayed along with the pagination arrow
  if avaliable_pairs.size > 4
    avaliable_pairs = avaliable_pairs[state[:quote_offset], 3]
    pagination = true
  end

  pairs = avaliable_pairs.map do |item|
    { text: item == state[:quote] ? "• #{item} •" : item, callback_data: "#{state[:base]}[#{state[:base_offset]}]:#{state[:source]}[#{state[:source_offset]}]:#{item}[#{state[:quote_offset]}]" }
  end

  pairs << { text: '→', callback_data: "#{state[:base]}[#{state[:base_offset]}]:#{state[:source]}[#{state[:source_offset]}]:#{state[:quote]}[#{state[:quote_offset] + 1}]" } if pagination

  {
    inline_keyboard: [
      [
        { text: "• #{data_source.name} •", callback_data: "#{state[:base]}[#{state[:base_offset]}]:#{state[:source]}[#{state[:source_offset]}]:#{state[:quote]}[#{state[:quote_offset]}]" }
      ],
      pairs
    ]
  }
end

def data_sources_map
  {
    'coingecko' => DataSource::CoinGecko,
    'coinmarketcap' => DataSource::CoinMarketCap,
    'binance' => DataSource::Binance
  }
end

def log_request(event, account_id)
  puts event.to_json

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
