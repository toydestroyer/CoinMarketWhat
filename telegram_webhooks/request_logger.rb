# frozen_string_literal: true

class RequestLogger
  def self.enqueue(event, account_id)
    puts event.to_json

    Lambda.sqs.send_message(
      queue_url: "https://sqs.eu-north-1.amazonaws.com/#{account_id}/CoinMarketWhatLogsQueue",
      message_body: event.to_json
    )
  end

  def self.save(logs)
    logs.each do |log|
      body = JSON.parse(log['body'])
      update_id = body.delete('update_id')

      raise 'missing update_id' unless update_id
      raise 'only 1 key can be processed' unless body.keys.size == 1

      event_type = body.keys.first
      raise "unsupported event_type: #{event_type}" unless allowed_events.include?(event_type)

      time = Time.at(0, log['attributes']['SentTimestamp'].to_i, :millisecond)

      Lambda.s3.put_object(
        body: body[event_type].to_json,
        bucket: ENV['LOGS_BUCKET'],
        key: "#{event_type}/#{time_prefix(time)}/#{update_id}.json"
      )
    end
  end

  def self.time_prefix(time)
    time.strftime('%Y/%m/%d/%H')
  end

  # There are much more possible events, but I want to be in control of which one to store
  def self.allowed_events
    %w[callback_query chosen_inline_result inline_query message]
  end
end
