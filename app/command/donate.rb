# frozen_string_literal: true

module Command
  class Donate < Base
    def message
      {
        text:,
        parse_mode: 'MarkdownV2'
      }
    end

    private

    def text
      <<~MARKDOWNV2
        #{addresses_list}
      MARKDOWNV2
    end

    def addresses_list
      JSON.parse(ENV.fetch('DONATION_ADDRESS')).map { |k, v| "#{k}: `#{v}`" }.join("\n")
    end
  end
end
