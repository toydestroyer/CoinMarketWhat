# frozen_string_literal: true

module Telegram
  class User
    attr_reader :id, :username, :first_name, :last_name, :language_code, :is_bot

    def initialize(params)
      @id = params['id']
      @username = params['username']
      @first_name = params['first_name']
      @last_name = params['last_name']
      @language_code = params['language_code']
      @is_bot = params['is_bot']

      @params = params
    end

    def register
      return if registered?

      Lambda.dynamodb.put_item(
        table_name: ENV['DYNAMODB_TABLE_NAME'],
        item: params.merge(resource_type: 'telegram/user', resource_id: id.to_s, created_at: Time.now.to_i)
      )
    end

    def registered?
      @registered ||= begin
        result = Lambda.dynamodb.get_item(
          table_name: ENV['DYNAMODB_TABLE_NAME'],
          key: { resource_type: 'telegram/user', resource_id: id.to_s }
        )

        result.item
      end
    end

    def unregistered?
      @unregistered ||= !registered?
    end

    private

    attr_reader :params
  end
end
