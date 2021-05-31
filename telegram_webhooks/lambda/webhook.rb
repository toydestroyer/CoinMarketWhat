# frozen_string_literal: true

module Lambda
  class Webhook < Base
    @trigger = :api_gateway

    HANDLERS_MAP = {
      'inline_query' => Handler::InlineQuery,
      'callback_query' => Handler::CallbackQuery
    }.freeze

    attr_reader :body

    def initialize(event:)
      super

      @body = JSON.parse(event['body'])
      EventLog.enqueue(event['body'])
    end

    def process
      return { statusCode: 200, body: '' } unless HANDLERS_MAP.key?(event_name)

      # call .respond to render command back to telegram immediately
      # or .process to send the command with a separate HTTP request
      result = HANDLERS_MAP[event_name].new(body[event_name]).respond

      { statusCode: 200, body: result.to_json }
    end

    def event_name
      @event_name ||= body.keys.reject { |key| key == 'update_id' }.first
    end

    def current_user
      @current_user ||= body[event_name]['from']
    end

    def sentry_extras
      { user: current_user }
    end
  end
end
