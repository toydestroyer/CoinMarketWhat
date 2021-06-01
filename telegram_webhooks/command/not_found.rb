# frozen_string_literal: true

module Command
  class NotFound < Base
    def message
      {
        text: "Command `#{command}` not found",
        parse_mode: 'MarkdownV2'
      }
    end
  end
end
