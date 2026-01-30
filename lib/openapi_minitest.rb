# frozen_string_literal: true

require_relative "openapi_minitest/version"
require_relative "openapi_minitest/configuration"
require_relative "openapi_minitest/result_collector"
require_relative "openapi_minitest/dsl"
require_relative "openapi_minitest/openapi/generator"

require_relative "openapi_minitest/railtie" if defined?(Rails::Railtie)

module OpenapiMinitest
  class Error < StandardError; end
  class SchemaValidationError < Error; end
end
