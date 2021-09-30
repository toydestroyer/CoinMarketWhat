# frozen_string_literal: true

module Command
  class Help < Base
    def message
      {
        # This file_id is not confidential and could be safely stored in the repo
        animation: 'CgACAgIAAxkBAAIBKmDAwx7TbRAgmXfXN9OBX7hTdQZdAAKWDAACo3gISs_Z8XFQcfifHwQ'
      }
    end

    def method_name
      'sendAnimation'
    end
  end
end
