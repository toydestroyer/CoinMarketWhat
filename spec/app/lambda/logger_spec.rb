# frozen_string_literal: true

RSpec.describe Lambda::Logger, :with_lambda do
  let(:event) { { 'Records' => records } }
  let(:records) { [{ 'Sns' => { 'Message' => body, 'Timestamp' => '2021-05-18T12:45:07.000Z' } }] }
  let(:body) { file_fixture('telegram/callback_query.json') }
  let(:s3) { Lambda.s3 }

  it 'creates s3 object' do
    expect { result }.to change { s3.list_objects(bucket: ENV.fetch('LOGS_BUCKET')).contents.size }.from(0).to(1)
  end

  it 'saves object with correct key' do
    result

    key = 'callback_query/year=2021/month=05/day=18/hour=12/1.json'
    object = s3.get_object(bucket: ENV.fetch('LOGS_BUCKET'), key:)
    expect(object).to be_any
  end
end
