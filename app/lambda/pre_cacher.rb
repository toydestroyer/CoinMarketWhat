# frozen_string_literal: true

module Lambda
  class PreCacher < Base
    def process
      puts "Records: #{event['Records'].size}"

      event['Records'].each do |record|
        record = JSON.parse(record['body'])

        record.each do |id, data_sources|
          data_sources.each do |slug, quotes|
            data_source = DATA_SOURCES_MAP[slug]

            data_source.fetch_batch_prices(id: id, quotes: quotes)
          end
        end
      end
    end
  end
end
