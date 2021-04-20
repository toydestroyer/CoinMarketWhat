require 'json'

def lambda_handler(event:, context:)
  {
    statusCode: 200,
    body: {
      message: "Hello World!"
    }.to_json
  }
end
