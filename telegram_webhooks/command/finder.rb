# frozen_string_literal: true

module Command
  class Finder
    class << self
      COMMANDS_MAP = {
        '/start' => Command::Start,
        '/about' => Command::Start,
        '/help' => Command::HowTo,
        '/howto' => Command::HowTo,
        '/donate' => Command::Donate
      }.freeze

      def by_command(command)
        COMMANDS_MAP[command] || Command::NotFound
      end
    end
  end
end
