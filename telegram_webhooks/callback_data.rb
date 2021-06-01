# frozen_string_literal: true

class CallbackData
  class << self
    def parse(data)
      validate!(data: data)

      result = data.split(PATTERN).drop(1)

      new(base: result[0], source: result[1], source_offset: result[2], quote: result[3], quote_offset: result[4])
    end

    def validate!(data:)
      raise "data length exceed #{MAX_LENGTH} chars" if data.length > MAX_LENGTH
      raise "data doesn't match expected pattern" unless PATTERN.match?(data)
    end
  end

  attr_accessor :base, :source, :source_offset, :quote, :quote_offset

  # Telegram Bot API limitation
  MAX_LENGTH = 64
  PATTERN = /^([\w-]+?):(\w+?)\[(\d+)\]:(\w+?)\[(\d+)\]$/.freeze

  def initialize(base:, source:, quote:, source_offset: 0, quote_offset: 0)
    @base = base
    @source = source
    @source_offset = source_offset.to_i
    @quote = quote
    @quote_offset = quote_offset.to_i
  end

  def visible
    result = {}

    DATA_SOURCES_MAP.each do |slug, data_source|
      result[slug] = if slug == source
                       visible_pairs(data_source: data_source, offset: quote_offset).uniq
                     else
                       [data_source.matching_pair(id: base, matching: quote)]
                     end
    end

    result
  end

  def visible_pairs(data_source:, offset:, limit: 4)
    pairs = data_source.pairs(id: base)

    if pairs.size > limit
      offset = pairs.size if offset > pairs.size
      visible_list = pairs[offset, limit - 1]
      visible_list += pairs[0, limit - visible_list.size - 1] if visible_list.size < limit - 1

      return (visible_list << quote)
    end

    pairs
  end

  def to_s
    data = "#{base}:#{source}[#{source_offset}]:#{quote}[#{quote_offset}]"
    self.class.validate!(data: data)

    data
  end
end
