# frozen_string_literal: true

module Lambda
  class Base
    class << self
      attr_accessor :trigger

      def call(event:, **)
        handler = new(event:)
        handler.process
      rescue StandardError => e
        ExceptionHandler.call(e, event:, **handler&.sentry_extras)

        # Log exception to Sentry and swallow it, because I don't want Telegram to resend the event
        return { statusCode: 200, body: '' } if trigger == :api_gateway

        raise e
      end
    end

    attr_reader :event

    def initialize(event:)
      @event = event
    end

    def process
      raise 'not implemented'
    end

    def sentry_extras
      {}
    end
  end
end
