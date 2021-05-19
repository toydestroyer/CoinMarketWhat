# frozen_string_literal: true

require_relative '../telegram_webhooks/lambda'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow: 'localstack:4566', allow_localhost: true)

RSpec.configure do |config|
  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # This option will default to `:apply_to_host_groups` in RSpec 4 (and will
  # have no way to turn it off -- the option exists only for backwards
  # compatibility in RSpec 3). It causes shared context metadata to be
  # inherited by the metadata hash of host groups and examples, rather than
  # triggering implicit auto-inclusion in groups with matching metadata.
  config.shared_context_metadata_behavior = :apply_to_host_groups

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

def file_fixture(path)
  File.read("./spec/fixtures/#{path}")
end

def json_fixture(path)
  JSON.parse(file_fixture(path))
end
