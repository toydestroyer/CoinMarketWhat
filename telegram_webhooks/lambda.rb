# frozen_string_literal: true

require 'json'
require 'aws-sdk-dynamodb'
require 'aws-sdk-sqs'
require 'aws-sdk-s3'
require 'aws-sdk-ssm'
require 'rest-client'
require 'money'
require 'sentry-ruby'

require_relative './handler/base'
require_relative './handler/callback_query'
require_relative './handler/inline_query'

require_relative './data_source/base'
require_relative './data_source/binance'
require_relative './data_source/coingecko'
require_relative './cacher'
require_relative './event_log'
require_relative './request_logger'
require_relative './searcher'

I18n.enforce_available_locales = false
Money.default_infinite_precision = true
Money.locale_backend = :currency
# Temporary™ solution to observe requests latency during development
RestClient.log = $stdout

class Lambda
  def self.webhook(event:, context:)
    body = JSON.parse(event['body'])
    RequestLogger.enqueue(body)

    Handler::InlineQuery.new(body['inline_query']) if body.key?('inline_query')
    Handler::CallbackQuery.new(body['callback_query']) if body.key?('callback_query')

    { statusCode: 200, body: 'ok' }
  rescue StandardError => e
    event['body'] = body
    event_name = event_name(body.keys)
    capture_exception(exception: e, event: event, context: context, user: body[event_name]['from'])

    { statusCode: 200, body: 'ok' }
  end

  def self.cache(event:, context:)
    cacher = Cacher.new
    cacher.call
  rescue StandardError => e
    capture_exception(exception: e, event: event, context: context)
  end

  def self.logger(event:, context:)
    RequestLogger.save(event['Records'])
  rescue StandardError => e
    capture_exception(exception: e, event: event, context: context)
  end

  def self.event_name(keys)
    keys.reject { |key| key == 'update_id' }.first
  end

  def self.capture_exception(exception:, event:, context:, user: nil)
    Sentry.with_scope do |scope|
      scope.set_user(user)
      scope.set_extras(event)
      scope.set_tags(
        function_name: context.function_name,
        memory_limit_in_mb: context.memory_limit_in_mb,
        function_version: context.function_version,
        aws_region: ENV['AWS_REGION']
      )

      Sentry.capture_exception(exception)
    end
  end

  def self.dynamodb
    @dynamodb ||= Aws::DynamoDB::Client.new(aws_config)
  end

  def self.sqs
    @sqs ||= Aws::SQS::Client.new(aws_config)
  end

  def self.s3
    @s3 ||= begin
      config = aws_config
      # https://github.com/localstack/localstack/issues/472
      config = aws_config.merge(force_path_style: true) if ENV.key?('LOCALSTACK_ENDPOINT')
      Aws::S3::Client.new(config)
    end
  end

  def self.ssm
    @ssm ||= Aws::SSM::Client.new(aws_config)
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

  def self.aws_config
    @aws_config ||= begin
      config = { region: ENV['AWS_REGION'] }
      config[:endpoint] = ENV['LOCALSTACK_ENDPOINT'] if ENV.key?('LOCALSTACK_ENDPOINT')

      config
    end
  end
end

Sentry.init do |config|
  # Skip parameter lookup in development environment
  unless ENV.key?('LOCALSTACK_ENDPOINT')
    config.dsn = Lambda.ssm.get_parameter(name: '/config/sentry_dsn').parameter.value
  end

  # Send events synchronously
  config.background_worker_threads = 0
end
