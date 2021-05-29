# frozen_string_literal: true

class EventLog
  attr_reader :body, :update_id, :event_type, :time

  def initialize(log)
    @body = JSON.parse(log['body'])
    @update_id = @body.delete('update_id')

    raise 'missing update_id' unless @update_id
    raise 'only 1 key can be processed' unless @body.keys.size == 1

    @event_type = @body.keys.first
    @time = Time.at(0, log['attributes']['SentTimestamp'].to_i, :millisecond)
  end

  def save
    Lambda.s3.put_object(
      body: body[event_type].to_json,
      bucket: ENV['LOGS_BUCKET'],
      key: key
    )
  end

  private

  def key
    "#{event_type}/#{time_prefix}/#{update_id}.json"
  end

  def time_prefix
    time.strftime('%Y/%m/%d/%H')
  end
end
