module DataSource
  class Base
    def available_assets
      @available_assets ||= load_assets
    end
  end
end
