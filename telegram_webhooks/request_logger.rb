# frozen_string_literal: true

class RequestLogger
  def self.enqueue(event)
    puts event.to_json

    Lambda.sqs.send_message(
      queue_url: ENV['LOGS_QUEUE'],
      message_body: event.to_json
    )
  end

  def self.save(logs)
    logs.each do |log|
      event_log = EventLog.new(log)
      event_log.save
    end
  end
end
