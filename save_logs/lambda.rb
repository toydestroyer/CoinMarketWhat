require 'json'
require 'aws-sdk-s3'

def handler(event:, context:)
  logs = event['Records']
  logs.each do |log|
    body = JSON.parse(log['body'])
    update_id = body.delete('update_id')

    raise 'missing update_id' unless update_id
    raise 'only 1 key can be processed' unless body.keys.size == 1

    event_type = body.keys.first
    raise "unsupported event_type: #{event_type}" unless allowed_events.include?(event_type)

    time = Time.at(0, log['attributes']['SentTimestamp'].to_i, :millisecond)

    s3.put_object({
      body: body[event_type].to_json,
      bucket: ENV['S3_BUCKET_NAME'],
      key: "#{event_type}/#{time_prefix(time)}/#{update_id}.json",
    })
  end
end

def time_prefix(time)
  time.strftime("%Y/%m/%d/%H")
end

# There are much more possible events, but I want to be in control of which one to store
def allowed_events
  ['callback_query', 'chosen_inline_result', 'inline_query', 'message']
end

def s3
  @s3 ||= Aws::S3::Client.new(region: 'eu-north-1')
end
