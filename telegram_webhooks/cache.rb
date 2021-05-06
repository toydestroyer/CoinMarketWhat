# frozen_string_literal: true

require 'json'
require 'aws-sdk-s3'
require 'rest-client'

require_relative './data_source/base'
require_relative './data_source/coingecko'
require_relative './data_source/coinmarketcap'

# rubocop:disable Lint/UnusedMethodArgument
def lambda_handler(event:, context:)
  # rubocop:enable Lint/UnusedMethodArgument
  raise unless event.key?('data_source') && %w[CoinGecko CoinMarketCap].include?(event['data_source'])

  data_source = Object.const_get("DataSource::#{event['data_source']}")
  data_source.cache_assets
end
