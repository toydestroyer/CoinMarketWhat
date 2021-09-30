# frozen_string_literal: true

module Lambda
  class Webhook < Base
    @trigger = :api_gateway

    attr_reader :body

    def initialize(event:)
      super

      @body = JSON.parse(event['body'])
      EventLog.enqueue(event['body'], event_name: event_name)
    end

    def process
      handler = "Handler::#{event_name.classify}".constantize

      # call .respond to render command back to telegram immediately
      # or .process to send the command with a separate HTTP request
      result = handler.new(body[event_name]).respond

      { statusCode: 200, body: result.to_json }
    rescue NameError
      { statusCode: 200, body: '' }
    end

    def sentry_extras
      { user: current_user }
    end

    private

    def event_name
      @event_name ||= body.keys.reject { |key| key == 'update_id' }.first
    end

    def current_user
      @current_user ||= body[event_name]['from']
    end
  end
end
