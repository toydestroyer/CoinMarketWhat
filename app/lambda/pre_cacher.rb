# frozen_string_literal: true

module Lambda
  class PreCacher < Base
    def process
      puts "Records: #{event['Records'].size}"

      event['Records'].each do |record|
        event_name = record['Sns']['MessageAttributes']['event_name']['Value']

        case event_name
        when 'callback_query'
          cache_callback_query(record['Sns']['Message'])
        when 'chosen_inline_result'
          # TODO
        end
      end
    end

    private

    def cache_callback_query(message)
      query = JSON.parse(message)
      state = CallbackData.parse(query['callback_query']['data'])

      state.visible.each do |slug, quotes|
        data_source = DATA_SOURCES_MAP[slug]
        data_source.fetch_batch_prices(id: state.base, quotes:)
      end
    end
  end
end
