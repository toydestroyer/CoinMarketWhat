# frozen_string_literal: true

class Searcher
  class << self
    def call(query:)
      return top if query.empty?

      exact_match = get_exact_match(query: query)

      return exact_match if exact_match.size == 10

      partial_match = get_partial_match(query: query, skip: exact_match.keys)

      exact_match.merge(partial_match)
    end

    private

    def get_exact_match(query:)
      result = DataSource::CoinGecko.available_assets.select do |_k, v|
        v['symbol'].casecmp(query).zero? || v['name'].casecmp(query).zero?
      end

      result.first(10).to_h
    end

    def get_partial_match(query:, skip:)
      result = DataSource::CoinGecko.available_assets.select do |k, v|
        !skip.include?(k) && (v['symbol'].start_with?(query.upcase) || v['name'].downcase.start_with?(query.downcase))
      end

      result.first(10 - skip.size).to_h
    end

    def top
      DataSource::CoinGecko.available_assets.first(10).to_h
    end
  end
end
