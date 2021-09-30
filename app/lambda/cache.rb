# frozen_string_literal: true

module Lambda
  class Cache < Base
    def process
      cacher = Cacher.new
      cacher.call
    end
  end
end
