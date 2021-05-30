# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    Lambda.sqs.create_queue(queue_name: 'CoinMarketWhatLogsQueue')
    Lambda.s3.create_bucket(bucket: ENV['LOGS_BUCKET'])
  end

  config.after(:suite) do
    Lambda.sqs.delete_queue(queue_url: ENV['LOGS_QUEUE'])
    Lambda.s3.delete_bucket(bucket: ENV['LOGS_BUCKET'])
  end

  config.after do
    # Remove all objects across all buckets after each example
    Lambda.s3.list_buckets.buckets.each do |bucket|
      Lambda.s3.list_objects(bucket: bucket.name).contents.each do |file|
        Lambda.s3.delete_object(
          bucket: bucket.name,
          key: file.key
        )
      end
    end

    # Remove all messages across all queues after each example
    # Lambda.sqs.list_queues.queue_urls.each do |queue_url|
    #   Lambda.sqs.purge_queue(queue_url: queue_url)
    # end
  end
end
