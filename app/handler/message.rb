# frozen_string_literal: true

module Handler
  class Message < Base
    attr_reader :id, :chat, :from, :text, :entities, :admin_chat_id

    def initialize(payload)
      super

      @id = payload['message_id']
      @chat = payload['chat']
      @from = payload['from']
      @text = payload['text']
      @entities = payload['entities']
      @admin_chat_id = ENV['TELEGRAM_ADMIN_CHAT_ID'].to_i

      forward_message if should_be_forwarded?
      process_commands if bot_commands.any?
    end

    def respond; end

    def process; end

    private

    def bot_commands
      @bot_commands ||= if command_entities
                          command_entities.map { |command| text[command['offset'], command['length']].downcase }.uniq
                        else
                          []
                        end
    end

    def command_entities
      @command_entities ||= if entities
                              entities.select { |entity| entity['type'] == 'bot_command' }
                            else
                              []
                            end
    end

    def process_commands
      bot_commands.each do |bot_command|
        command_class = CommandFinder.by_command(bot_command)
        command = command_class.new(command: bot_command, user:, chat:)
        command.process
      end
    end

    def start_from_command?
      command_entities.detect { |entity| entity['offset'].zero? }
    end

    def forward_message
      puts RestClient.post(
        "https://api.telegram.org/bot#{ENV.fetch('TELEGRAM_BOT_API_TOKEN')}/forwardMessage",
        chat_id: admin_chat_id,
        from_chat_id: chat['id'],
        disable_notification: true,
        message_id: id
      )
    end

    def should_be_forwarded?
      !start_from_command? &&
        chat['type'] == 'private' &&
        chat['id'] == from['id'] &&
        chat['id'] != admin_chat_id
    end
  end
end
