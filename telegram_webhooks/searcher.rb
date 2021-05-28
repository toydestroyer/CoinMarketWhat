# frozen_string_literal: true

class Searcher
  class << self
    def call(query:)
      return top if query.empty?

      # Get exact match
      exact_match = DataSource::CoinGecko.available_assets.select { |_k, v| v['symbol'].casecmp(query).zero? || v['name'].casecmp(query).zero? }.first(10).to_h

      return exact_match if exact_match.size == 10

      exact_ids = exact_match.map { |k, _v| k }
      partial_match = DataSource::CoinGecko.available_assets.select { |k, v| !exact_ids.include?(k) && (v['symbol'].start_with?(query.upcase) || v['name'].downcase.start_with?(query.downcase)) }.first(10 - exact_match.size).to_h

      exact_match.merge(partial_match)
    end

    def top
      DataSource::CoinGecko.available_assets.first(10).to_h
    end
  end
end
