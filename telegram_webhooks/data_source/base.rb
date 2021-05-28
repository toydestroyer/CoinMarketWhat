# frozen_string_literal: true

module DataSource
  class Base
    class << self
      def display_name
        raise 'not implemented'
      end

      def slug
        @slug ||= display_name.downcase
      end

      def available_assets
        @available_assets ||= load_assets
      end

      def pairs(id:)
        CoinGecko.available_assets[id]['tickers'][slug]['quotes']
      end
    end
  end
end
