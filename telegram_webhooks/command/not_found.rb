# frozen_string_literal: true

module Command
  class NotFound < Base
    def message
      {
        text: "Command #{command} not found"
      }
    end
  end
end
