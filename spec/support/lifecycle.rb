# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    Lambda.sqs.create_queue(queue_name: 'CoinMarketWhatLogsQueue')
    Lambda.s3.create_bucket(bucket: ENV['LOGS_BUCKET'])
    Lambda.s3.create_bucket(bucket: ENV['CACHE_BUCKET'])
    Lambda.s3.put_object(key: 'coingecko.json', bucket: ENV['CACHE_BUCKET'], body: file_fixture('coingecko.json'))
  end

  config.after(:suite) do
    Lambda.s3.delete_bucket(bucket: ENV['LOGS_BUCKET'])

    empty_bucket(ENV['CACHE_BUCKET'])
    Lambda.s3.delete_bucket(bucket: ENV['CACHE_BUCKET'])
  end

  config.after do
    empty_bucket(ENV['LOGS_BUCKET'])

    # Remove all objects across all buckets after each example
    # Lambda.s3.list_buckets.buckets.each do |bucket|
    #   empty_bucket(bucket.name)
    # end

    # Remove all messages across all queues after each example
    # Lambda.sqs.list_queues.queue_urls.each do |queue_url|
    #   Lambda.sqs.purge_queue(queue_url: queue_url)
    # end
  end

  def empty_bucket(name)
    Lambda.s3.list_objects(bucket: name).contents.each do |file|
      Lambda.s3.delete_object(
        bucket: name,
        key: file.key
      )
    end
  end
end
