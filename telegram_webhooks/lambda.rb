# frozen_string_literal: true

require 'json'
require 'aws-sdk-dynamodb'
require 'aws-sdk-sqs'
require 'aws-sdk-s3'
require 'aws-sdk-ssm'
require 'rest-client'
require 'money'

require_relative './handler/base'
require_relative './handler/callback_query'
require_relative './handler/inline_query'

require_relative './data_source/base'
require_relative './data_source/binance'
require_relative './data_source/coingecko'
require_relative './searcher'
require_relative './request_logger'

I18n.enforce_available_locales = false
Money.default_infinite_precision = true

class Lambda
  # rubocop:disable Lint/UnusedMethodArgument
  def self.webhook(event:, context:)
    body = JSON.parse(event['body'])
    RequestLogger.enqueue(body, event['requestContext']['accountId'])

    Handler::InlineQuery.new(body['inline_query']) if body.key?('inline_query')
    Handler::CallbackQuery.new(body['callback_query']) if body.key?('callback_query')

    { statusCode: 200, body: 'ok' }
  end

  def self.cache(event:, context:)
    raise unless event.key?('data_source') && %w[CoinGecko].include?(event['data_source'])

    data_source = Object.const_get("DataSource::#{event['data_source']}")
    data_source.cache_assets
  end

  def self.logger(event:, context:)
    RequestLogger.save(event['Records'])
  end
  # rubocop:enable Lint/UnusedMethodArgument

  def self.dynamodb
    @dynamodb ||= Aws::DynamoDB::Client.new(region: 'eu-north-1')
  end

  def self.sqs
    @sqs ||= Aws::SQS::Client.new(region: 'eu-north-1')
  end

  def self.s3
    @s3 ||= Aws::S3::Client.new(region: 'eu-north-1')
  end

  def self.ssm
    @ssm ||= Aws::SSM::Client.new(region: 'eu-north-1')
  end

  def self.token
    @token ||= ssm.get_parameter(name: '/bots/telegram/CoinMarketWhat').parameter.value
  end

  def self.data_sources_map
    {
      'coingecko' => DataSource::CoinGecko,
      'binance' => DataSource::Binance
    }
  end
end
