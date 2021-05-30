# frozen_string_literal: true

module Lambda
  class Webhook < Base
    HANDLERS_MAP = {
      'inline_query' => Handler::InlineQuery,
      'callback_query' => Handler::CallbackQuery
    }.freeze

    attr_reader :body

    def initialize(event:, context:)
      super

      @body = JSON.parse(event['body'])
    end

    def process
      HANDLERS_MAP[event_name].new(body[event_name]) if HANDLERS_MAP.key?(event_name)
    ensure
      EventLog.enqueue(event['body'])
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

    def self.render
      { statusCode: 200, body: 'ok' }
    end
  end
end
