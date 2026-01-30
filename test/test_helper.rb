# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "openapi_minitest"

require "minitest/autorun"

module OpenapiMinitest
  module TestHelpers
    def setup
      super
      OpenapiMinitest.reset!
    end
  end
end
