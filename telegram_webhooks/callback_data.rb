# frozen_string_literal: true

class CallbackData
  attr_accessor :base, :source, :source_offset, :quote, :quote_offset

  # Telegram Bot API limitation
  MAX_LENGTH = 64
  PATTERN = /^([\w-]+?):(\w+?)\[(\d+)\]:(\w+?)\[(\d+)\]$/.freeze

  def self.parse(data)
    validate!(data: data)

    result = data.split(PATTERN).drop(1)

    new(base: result[0], source: result[1], source_offset: result[2], quote: result[3], quote_offset: result[4])
  end

  def self.validate!(data:)
    raise "data length exceed #{MAX_LENGTH} chars" if data.length > MAX_LENGTH
    raise "data doesn't match expected pattern" unless PATTERN.match?(data)
  end

  def initialize(base:, source:, quote:, source_offset: 0, quote_offset: 0)
    @base = base
    @source = source
    @source_offset = source_offset.to_i
    @quote = quote
    @quote_offset = quote_offset.to_i
  end

  def to_s
    data = "#{base}:#{source}[#{source_offset}]:#{quote}[#{quote_offset}]"
    self.class.validate!(data: data)

    data
  end
end
