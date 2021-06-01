# frozen_string_literal: true

module Handler
  class Message < Base
    attr_reader :id, :chat, :text, :entities, :admin_chat_id

    def initialize(query)
      super

      @id = query['message_id']
      @chat = query['chat']
      @text = query['text']
      @entities = query['entities']
      @admin_chat_id = ENV['TELEGRAM_ADMIN_CHAT_ID']

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
        command_class = Command::Finder.by_command(bot_command)
        command = command_class.new(command: bot_command, user: user, chat: chat)
        command.process
      end
    end

    def start_from_command?
      command_entities.detect { |entity| entity['offset'].zero? }
    end

    def forward_message
      RestClient.get(
        "https://api.telegram.org/bot#{token}/forwardMessage",
        params: {
          chat_id: admin_chat_id,
          from_chat_id: chat['id'],
          disable_notification: true,
          message_id: id
        }
      )
    end

    def should_be_forwarded?
      !start_from_command? && chat['id'] != admin_chat_id.to_i
    end
  end
end
