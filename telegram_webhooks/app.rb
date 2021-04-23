require 'json'
require 'aws-sdk-dynamodb'
require 'aws-sdk-ssm'
require 'rest-client'

def lambda_handler(event:, context:)
  log_request(event)
  render_inline(JSON.parse(event['body'])['inline_query']) if JSON.parse(event['body']).key?('inline_query')

  {
    statusCode: 200,
    body: 'ok'
  }
end

def render_inline(query)
  result = []
  result << { type: :article, id: SecureRandom.hex, title: "BTC/USDT", thumb_url: "https://dummyimage.com/512x512/ffffff/000000.png&text=BTC/USDT", input_message_content: { message_text: "BTC/USDT" }}
  result << { type: :article, id: SecureRandom.hex, title: "ETH/USDT", thumb_url: "https://dummyimage.com/512x512/ffffff/000000.png&text=ETH/USDT", input_message_content: { message_text: "ETH/USDT" }}
  result << { type: :article, id: SecureRandom.hex, title: "ETH/BTC", thumb_url: "https://dummyimage.com/512x512/ffffff/000000.png&text=ETH/USDT", input_message_content: { message_text: "ETH/BTC" }}

  RestClient.get("https://api.telegram.org/bot#{token}/answerInlineQuery", params: {
    inline_query_id: query['id'],
    results: result.to_json,
    cache_time: 0
  })
rescue => e
  puts e.response.to_json
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
  @dynamodb ||= Aws::DynamoDB::Client.new(region: 'ap-southeast-1')
end

def ssm
  @ssm ||= Aws::SSM::Client.new(region: 'ap-southeast-1')
end

def token
  @token ||= ssm.get_parameter(name: '/bots/telegram/CoinMarketWhat').parameter.value
end
