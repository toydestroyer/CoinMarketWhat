# frozen_string_literal: true

require 'json'
require 'aws-sdk-s3'
require 'rest-client'

require_relative './data_source/base'
require_relative './data_source/coingecko'
require_relative './data_source/coinmarketcap'

def lambda_handler(event:, context:)
  raise unless event.key?('data_source') && ['CoinGecko', 'CoinMarketCap'].include?(event['data_source'])

  data_source = Object.const_get("DataSource::#{event['data_source']}")
  data_source.cache_assets
end
