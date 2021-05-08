# frozen_string_literal: true

module Handler
  class Base
    attr_reader :query, :token

    def initialize(query)
      @query = query
      @token = Lambda.token

      handle
    end

    def handle
      raise 'not implemented'
    end

    def build_inline_query_answer(query:)
      selected = Searcher.call(query: query)

      return [] if selected.empty?

      selected_ids = selected.map { |item| item['id'] }
      prices = DataSource::CoinGecko.prices(ids: selected_ids)

      result = prices.map do |symbol|
        price = Money.from_amount(symbol['current_price'], 'USD').format

        title = "#{symbol['name']} (#{symbol['symbol'].upcase})"

        initial_state = decompose_callback_data("#{symbol['id']}[0]:coingecko[0]:USD[0]")

        {
          type: :article,
          id: SecureRandom.hex,
          title: title,
          description: "#{price} @ CoinGecko",
          thumb_url: symbol['image'],
          thumb_width: 250,
          thumb_height: 250,
          input_message_content: {
            message_text: "#{title} — #{price}"
          },
          reply_markup: build_reply_markup(initial_state)
        }
      end

      result.to_json
    end

    def build_reply_markup(state)
      data_source = Lambda.data_sources_map[state[:source]]
      avaliable_pairs = data_source.pairs(id: state[:base])

      pagination = false

      # Due to display concerns, I want to limit the number of buttons in the row to 4
      # If available pairs more than 4 then only 3 will be displayed along with the pagination arrow
      if avaliable_pairs.size > 4
        avaliable_pairs = avaliable_pairs[state[:quote_offset], 3]
        pagination = true
      end

      pairs = avaliable_pairs.map do |item|
        { text: item == state[:quote] ? "• #{item} •" : item, callback_data: "#{state[:base]}[#{state[:base_offset]}]:#{state[:source]}[#{state[:source_offset]}]:#{item}[#{state[:quote_offset]}]" }
      end

      pairs << { text: '→', callback_data: "#{state[:base]}[#{state[:base_offset]}]:#{state[:source]}[#{state[:source_offset]}]:#{state[:quote]}[#{state[:quote_offset] + 1}]" } if pagination

      {
        inline_keyboard: [
          [
            {
              text: "• #{data_source.name} •",
              callback_data: "#{state[:base]}[#{state[:base_offset]}]:#{state[:source]}[#{state[:source_offset]}]:#{state[:quote]}[#{state[:quote_offset]}]"
            }
          ],
          pairs
        ]
      }
    end

    def decompose_callback_data(data)
      result = data.split(/^([\w-]+?)\[(\d+)\]:(\w+?)\[(\d+)\]:(\w+?)\[(\d+)\]$/).drop(1)

      {
        base: result[0],
        base_offset: result[1].to_i,
        source: result[2],
        source_offset: result[3].to_i,
        quote: result[4],
        quote_offset: result[5].to_i
      }
    end
  end
end
