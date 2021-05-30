# frozen_string_literal: true

RSpec.configure do |_config|
  def file_fixture(path)
    File.read("./spec/fixtures/#{path}")
  end

  def json_fixture(path)
    JSON.parse(file_fixture(path))
  end
end
