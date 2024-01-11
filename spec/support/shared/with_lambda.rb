# frozen_string_literal: true

RSpec.shared_context 'with lambda' do
  subject(:result) { described_class.call(event:, context:) }

  let(:context) do
    instance_double('LambdaContext',
                    function_name: 'FunctionName',
                    memory_limit_in_mb: 128,
                    function_version: '$LATEST')
  end

  let(:event) { { 'body' => body.to_json } }
  let(:body) { {} }
end
