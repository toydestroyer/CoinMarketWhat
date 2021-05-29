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

      selected_ids = selected.keys
      prices = DataSource::CoinGecko.prices(ids: selected_ids, quote: 'USD')

      result = prices.map { |symbol| render_inline_query_item(symbol) }

      result.to_json
    end

    def build_reply_markup(state)
      {
        inline_keyboard: [
          build_data_sources_row(state),
          build_pairs_row(state)
        ]
      }
    end

    def decompose_callback_data(data)
      result = data.split(/^([\w-]+?):(\w+?)\[(\d+)\]:(\w+?)\[(\d+)\]$/).drop(1)

      {
        base: result[0],
        source: result[1],
        source_offset: result[2].to_i,
        quote: result[3],
        quote_offset: result[4].to_i
      }
    end

    private

    def render_inline_query_item(symbol)
      price = Money.from_amount(symbol['current_price'], 'USD').format
      title = "#{symbol['name']} (#{symbol['symbol'].upcase})"
      initial_state = decompose_callback_data("#{symbol['id']}:coingecko[0]:USD[0]")

      {
        type: :article,
        id: "#{symbol['id']}:coingecko:USD",
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

    def build_pairs_row(state)
      data_source = Lambda.data_sources_map[state[:source]]
      avaliable_pairs = data_source.pairs(id: state[:base])
      total_pairs = avaliable_pairs.size

      paginated, avaliable_pairs = paginate(list: avaliable_pairs, offset: state[:quote_offset])

      pairs = avaliable_pairs.map { |item| build_pair_button(item: item, state: state) }

      pairs << pagination_button(state: state, size: total_pairs, row: 'quote') if paginated

      pairs
    end

    def build_pair_button(item:, state:)
      {
        text: item == state[:quote] ? "• #{item} •" : item,
        callback_data: "#{state[:base]}:#{state[:source]}[#{state[:source_offset]}]:#{item}[#{state[:quote_offset]}]"
      }
    end

    def build_data_sources_row(state)
      DataSource::CoinGecko.available_assets[state[:base]]['tickers'].keys.map do |item|
        build_data_source_button(item: item, state: state)
      end
    end

    def build_data_source_button(item:, state:)
      data_source = Lambda.data_sources_map[item]

      if item == state[:source] # selected
        text = "• #{data_source.display_name} •"
        quote = "#{state[:quote]}[#{state[:quote_offset]}]"
      else
        text = data_source.display_name
        quote = "#{data_source.pairs(id: state[:base])[0]}[0]"
      end

      { text: text, callback_data: "#{state[:base]}:#{item}[#{state[:source_offset]}]:#{quote}" }
    end

    def paginate(list:, offset:, limit: 4)
      # Due to display concerns, I want to limit the number of buttons in the row to 4
      # If available pairs more than 4 then only 3 will be displayed along with the pagination arrow
      if list.size > limit
        offset = list.size if offset > list.size
        visible_list = list[offset, limit - 1]
        visible_list += list[0, limit - visible_list.size - 1] if visible_list.size < limit - 1

        return true, visible_list
      end

      [false, list]
    end

    def pagination_button(state:, size:, row:)
      state["#{row}_offset".to_sym] = 0 if state["#{row}_offset".to_sym] >= size
      state["#{row}_offset".to_sym] += 1
      source = "#{state[:source]}[#{state[:source_offset]}]"
      quote = "#{state[:quote]}[#{state[:quote_offset]}]"

      {
        text: '→',
        callback_data: "#{state[:base]}:#{source}:#{quote}"
      }
    end
  end
end
