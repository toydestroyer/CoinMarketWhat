# frozen_string_literal: true

class CommandFinder
  class << self
    ALIAS_COMMANDS = {
      '/about' => '/start',
      '/base' => '/not_found'
    }.freeze

    def by_command(command)
      command = ALIAS_COMMANDS[command] if ALIAS_COMMANDS.key?(command)

      "command#{command}".classify.constantize
    rescue NameError
      Command::NotFound
    end
  end
end
