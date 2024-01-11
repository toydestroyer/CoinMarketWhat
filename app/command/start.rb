# frozen_string_literal: true

module Command
  class Start < Base
    def process
      user.register if command == '/start'

      super
    end

    def message
      {
        text:,
        parse_mode: 'MarkdownV2',
        disable_web_page_preview: true,
        reply_markup: try_and_share.to_json
      }
    end

    private

    MARKDOWN_V2_ESCAPE_CHARS = ['_', '*', '[', ']', '(', ')', '~', '`', '>', '#', '+', '-', '=', '|', '{', '}', '.',
                                '!'].freeze

    def text
      <<~MARKDOWNV2
        #{greetings}\\! Glad to have you here\\.

        This is an _inline_ bot, that aims to help you instantly share the price of Bitcoin, Dogecoin or any other cryptocurrency price with your friend or with a group\\.

        It's currently in *beta* so only *CoinGecko* and *Binance* are supported\\. More exchanges will be added soon, so let me know which one you want\\.

        By the way, if you have any feedback, send a message to the bot\\.

        Because this bot is mainly focused on inline features, you can't do much in this chat, but here's the list of commands available:

        /help — show "how to" gif
        /about — show this message again
        /donate — I think you know what this command does 😉

        Lastly, this is an [open source](https://github.com/toydestroyer/CoinMarketWhat) project and I'm not making any money from it \\(currently\\)\\. So if you really enjoy it, please consider to /donate

        Well, enough talking\\! Go ahead and start using the bot by clicking the "Try" button below\\.
      MARKDOWNV2
    end

    def greetings
      if user.first_name
        first_name = markdown_v2_escape(user.first_name)
        "Hey there, #{first_name}"
      else
        'Hey there'
      end
    end

    def try_and_share
      {
        inline_keyboard: [
          [
            { text: 'Try', switch_inline_query_current_chat: '' },
            { text: 'Share', switch_inline_query: '' }
          ]
        ]
      }
    end

    def markdown_v2_escape(text)
      text.gsub(/./) { |char| MARKDOWN_V2_ESCAPE_CHARS.include?(char) ? "\\#{char}" : char }
    end
  end
end
