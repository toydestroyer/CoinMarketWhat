# frozen_string_literal: true

class ReplyMarkup
  attr_reader :state, :try_button

  def initialize(state:, try_button: false)
    @state = state
    @try_button = try_button
  end

  def render
    result = {
      inline_keyboard: [
        build_data_sources_row(state),
        build_pairs_row(state)
      ]
    }

    result[:inline_keyboard] << [{ text: 'Try it out', switch_inline_query_current_chat: '' }] if try_button

    result
  end

  private

  def build_pairs_row(state)
    data_source = DATA_SOURCES_MAP[state.source]
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
    data_source = DATA_SOURCES_MAP[item]

    if item == state.source # selected
      text = "• #{data_source.display_name} •"
    else
      text = data_source.display_name
      state.source = data_source.slug
      state.quote = data_source.matching_pair(id: state.base, matching: state.quote)
      state.quote_offset = data_source.pair_offset(id: state.base, quote: state.quote)
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
