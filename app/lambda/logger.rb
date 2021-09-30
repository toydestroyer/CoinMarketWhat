# frozen_string_literal: true

module Lambda
  class Logger < Base
    def process
      event['Records'].each do |log|
        event_log = EventLog.new(log['Sns'])
        event_log.save
      end
    end
  end
end
