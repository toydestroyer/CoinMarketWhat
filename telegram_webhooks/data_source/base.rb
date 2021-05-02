module DataSource
  class Base
    class << self
      def slug
        @slug ||= name.downcase
      end

      def available_assets
        @available_assets ||= load_assets
      end
    end
  end
end
