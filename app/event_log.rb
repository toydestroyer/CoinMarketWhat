# frozen_string_literal: true

class EventLog
  class << self
    def enqueue(event, event_name:)
      puts event

      Lambda.sns.publish(
        topic_arn: ENV['EVENTS_TOPIC'],
        message: event,
        message_attributes: {
          event_name: {
            data_type: 'String',
            string_value: event_name
          }
        }
      )
    end
  end

  attr_reader :body, :update_id, :event_type, :time

  def initialize(log)
    @body = JSON.parse(log['Message'])
    @update_id = @body.delete('update_id')

    raise 'missing update_id' unless @update_id
    raise 'only 1 key can be processed' unless @body.keys.size == 1

    @event_type = @body.keys.first
    @time = Time.parse(log['Timestamp'])
  end

  def save
    Lambda.s3.put_object(
      body: body[event_type].to_json,
      bucket: ENV['LOGS_BUCKET'],
      key:
    )
  end

  private

  def key
    "#{event_type}/#{time_prefix}/#{update_id}.json"
  end

  def time_prefix
    time.strftime('year=%Y/month=%m/day=%d/hour=%H')
  end
end
