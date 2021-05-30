# frozen_string_literal: true

module Lambda
  class Base
    def self.call(event:, context:)
      handler = new(event: event, context: context)
      handler.process

      render
    rescue StandardError => e
      capture_exception(e, context: context, event: event, **handler&.sentry_extras)

      render
    end

    def self.render
      true
    end

    def self.capture_exception(exception, context:, user: nil, **extras)
      return if skip_exception?(exception)

      if exception.is_a?(RestClient::ExceptionWithResponse)
        extras[:response] = response_exception_extras(exception.response)
      end

      Sentry.with_scope do |scope|
        scope.set_user(user) if user
        scope.set_extras(extras)

        tags = exception_tags(context: context)
        scope.set_tags(tags)

        Sentry.capture_exception(exception)
      end
    end

    def self.response_exception_extras(response)
      { body: response.body, code: response.code, headers: response.headers }
    end

    def self.exception_tags(context:)
      {
        function_name: context.function_name,
        memory_limit_in_mb: context.memory_limit_in_mb,
        function_version: context.function_version,
        aws_region: ENV['AWS_REGION']
      }
    end

    def self.skip_exception?(exception)
      return false unless exception.is_a?(RestClient::ExceptionWithResponse)

      JSON.parse(exception.response.body)['description'].start_with?('Bad Request: message is not modified')
    rescue NoMethodError
      false
    end

    attr_reader :event, :context

    def initialize(event:, context:)
      @event = event
      @context = context
    end

    def process
      raise 'not implemented'
    end

    def sentry_extras
      {}
    end
  end
end
