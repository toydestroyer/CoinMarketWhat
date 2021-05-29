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

    private

    def render_inline_query_item(symbol)
      price = Money.from_amount(symbol['current_price'], 'USD').format
      title = "#{symbol['name']} (#{symbol['symbol'].upcase})"
      initial_state = CallbackData.new(base: symbol['id'], source: 'coingecko', quote: 'USD')

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
      data_source = Lambda.data_sources_map[state.source]
      avaliable_pairs = data_source.pairs(id: state.base)
      total_pairs = avaliable_pairs.size

      paginated, avaliable_pairs = paginate(list: avaliable_pairs, offset: state.quote_offset)

      pairs = avaliable_pairs.map { |item| build_pair_button(item: item, state: state.dup) }

      pairs << pagination_button(state: state.dup, size: total_pairs, row: 'quote') if paginated

      pairs
    end

    def build_pair_button(item:, state:)
      text = item == state.quote ? "• #{item} •" : item
      state.quote = item

      {
        text: text,
        callback_data: state.to_s
      }
    end

    def build_data_sources_row(state)
      DataSource::CoinGecko.available_assets[state.base]['tickers'].keys.map do |item|
        build_data_source_button(item: item, state: state.dup)
      end
    end

    def build_data_source_button(item:, state:)
      data_source = Lambda.data_sources_map[item]

      if item == state.source # selected
        text = "• #{data_source.display_name} •"
      else
        text = data_source.display_name
        state.source = data_source.slug
        state.quote = data_source.pairs(id: state.base)[0]
        state.quote_offset = 0
      end

      {
        text: text,
        callback_data: state.to_s
      }
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
      state.send("#{row}_offset=", 0) if state.send("#{row}_offset") >= size
      state.send("#{row}_offset=", state.send("#{row}_offset") + 1)

      {
        text: '→',
        callback_data: state.to_s
      }
    end
  end
end
