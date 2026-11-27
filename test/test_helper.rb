ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end

# Простейшая заглушка метода на время блока: Minitest::Mock недоступен в
# bundled-поставке Minitest 6 (файл minitest/mock отсутствует).
def with_stub(object, method, implementation)
  original = object.method(method)
  object.define_singleton_method(method, implementation)
  yield
ensure
  object.define_singleton_method(method, original)
end
