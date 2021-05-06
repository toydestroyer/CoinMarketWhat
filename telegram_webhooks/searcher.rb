# frozen_string_literal: true
class Searcher
  class << self
    def call(query:)
      return top if query.empty?

      # Get exact match
      exact_match = DataSource::CoinGecko.available_assets.select { |item| item['symbol'].downcase == query.downcase || item['name'].downcase == query.downcase }.first(10)

      return exact_match if exact_match.size == 10

      exact_ids = exact_match.map { |item| item['id'] }
      partial_match = DataSource::CoinGecko.available_assets.select { |item| !exact_ids.include?(item['id']) && (item['symbol'].downcase.start_with?(query.downcase) || item['name'].downcase.start_with?(query.downcase)) }.first(10 - exact_match.size)

      exact_match + partial_match
    end

    def top
      DataSource::CoinGecko.available_assets.first(10)
    end
  end
end
