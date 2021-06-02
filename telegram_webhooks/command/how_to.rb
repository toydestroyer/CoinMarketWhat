# frozen_string_literal: true

module Command
  class HowTo < Base
    def message
      {
        # This file_id is not confidential and could be safely stored in the repo
        animation: 'CgACAgIAAxkBAAIBEGC2bkAfUjwJZ3tO9ilruSxFG0HYAALjDwAC9Yq4SdPqJ-4uf0VDHwQ'
      }
    end

    def method_name
      'sendAnimation'
    end
  end
end
