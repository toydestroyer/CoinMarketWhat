# frozen_string_literal: true

class ExceptionHandler
  class << self
    ENV_TAGS = %w[AWS_LAMBDA_FUNCTION_NAME AWS_LAMBDA_FUNCTION_MEMORY_SIZE AWS_LAMBDA_FUNCTION_VERSION
                  AWS_REGION].freeze

    attr_reader :extras, :user

    def call(exception, user: nil, **extras)
      return if skip_exception?(exception)

      @user = user
      @extras = extras

      if exception.is_a?(RestClient::ExceptionWithResponse)
        response = exception.response
        @extras[:response] = { body: response.body, code: response.code, headers: response.headers }
      end

      capture_exception(exception)
    end

    private

    def capture_exception(exception)
      Sentry.with_scope do |scope|
        scope.set_user(user) if user
        scope.set_extras(extras)
        scope.set_tags(tags)

        Sentry.capture_exception(exception)
      end
    end

    def tags
      ENV.slice(*ENV_TAGS)
    end

    # This method silence down Telegram errors that I shouldn't do anything about
    def skip_exception?(exception)
      return false unless exception.is_a?(RestClient::ExceptionWithResponse)

      JSON.parse(exception.response.body)['description'].start_with?('Bad Request: message is not modified')
    rescue NoMethodError
      false
    end
  end
end
