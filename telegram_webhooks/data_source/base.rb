# frozen_string_literal: true

module DataSource
  class Base
    class << self
      def slug
        @slug ||= name.downcase
      end

      def available_assets
        @available_assets ||= load_assets
      end

      def cache_assets
        # do nothing
      end
    end
  end
end
