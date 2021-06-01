# frozen_string_literal: true

require 'json'
require 'aws-sdk-dynamodb'
require 'aws-sdk-sqs'
require 'aws-sdk-s3'
require 'rest-client'
require 'money'
require 'sentry-ruby'

require_relative './command/base'
require_relative './command/donate'
require_relative './command/how_to'
require_relative './command/not_found'
require_relative './command/start'
require_relative './command/finder'

require_relative './handler/base'
require_relative './handler/callback_query'
require_relative './handler/inline_query'
require_relative './handler/message'

require_relative './telegram/user'

require_relative './lambda/base'
require_relative './lambda/cache'
require_relative './lambda/logger'
require_relative './lambda/webhook'

require_relative './data_source/base'
require_relative './data_source/binance'
require_relative './data_source/coingecko'

require_relative './cacher'
require_relative './callback_data'
require_relative './event_log'
require_relative './exception_handler'
require_relative './searcher'

Sentry.init do |config|
  # Send events synchronously
  config.background_worker_threads = 0
end

I18n.enforce_available_locales = false
Money.default_infinite_precision = true
Money.locale_backend = :currency

# Stop Money from formatting BTC and BCH
Money::Currency.unregister(:btc)
Money::Currency.unregister(:bch)

# Registed USD-attached stablecoins to render as USD
Money::Currency.inherit(:usd, iso_code: 'USDT', priority: 100)
Money::Currency.inherit(:usd, iso_code: 'USDC', priority: 100)
Money::Currency.inherit(:usd, iso_code: 'BUSD', priority: 100)
Money::Currency.inherit(:usd, iso_code: 'TUSD', priority: 100)

# Temporary™ solution to observe requests latency during development
RestClient.log = $stdout

DATA_SOURCES_MAP = {
  'coingecko' => DataSource::CoinGecko,
  'binance' => DataSource::Binance
}.freeze

module Lambda
  class << self
    def dynamodb
      @dynamodb ||= Aws::DynamoDB::Client.new(aws_config)
    end

    def sqs
      @sqs ||= Aws::SQS::Client.new(aws_config)
    end

    def s3
      @s3 ||= begin
        config = aws_config
        # https://github.com/localstack/localstack/issues/472
        config = aws_config.merge(force_path_style: true) if ENV.key?('LOCALSTACK_ENDPOINT')
        Aws::S3::Client.new(config)
      end
    end

    def aws_config
      @aws_config ||= begin
        config = { region: ENV['AWS_REGION'] }
        config[:endpoint] = ENV['LOCALSTACK_ENDPOINT'] if ENV.key?('LOCALSTACK_ENDPOINT')

        config
      end
    end
  end
end
