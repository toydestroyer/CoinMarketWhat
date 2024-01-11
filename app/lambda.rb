# frozen_string_literal: true

require 'json'
require 'aws-sdk-dynamodb'
require 'aws-sdk-sns'
require 'aws-sdk-sqs'
require 'aws-sdk-s3'
require 'active_support'
require 'active_support/core_ext'
require 'rest-client'
require 'money'
require 'sentry-ruby'
require 'zeitwerk'

loader = Zeitwerk::Loader.new
loader.push_dir(__dir__)
loader.inflector.inflect('coingecko' => 'CoinGecko')
loader.setup

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

    def sns
      @sns ||= Aws::SNS::Client.new(aws_config)
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
        config = { region: ENV.fetch('AWS_REGION') }
        config[:endpoint] = ENV['LOCALSTACK_ENDPOINT'] if ENV.key?('LOCALSTACK_ENDPOINT')

        config
      end
    end
  end
end
