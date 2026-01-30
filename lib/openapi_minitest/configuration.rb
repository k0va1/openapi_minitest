# frozen_string_literal: true

module OpenapiMinitest
  class Configuration
    attr_accessor :title,
      :version,
      :description,
      :output_path,
      :servers,
      :security_schemes,
      :tags,
      :validate_schema

    def initialize
      @title = "API Documentation"
      @version = "1.0.0"
      @description = nil
      @output_path = "doc/openapi.json"
      @servers = []
      @security_schemes = {}
      @tags = []
      @validate_schema = true
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset!
      @configuration = Configuration.new
      @schemas = {}
    end

    # Schema registry
    def schemas
      @schemas ||= {}
    end

    def define_schema(name, definition)
      schemas[name.to_sym] = definition
    end

    def schema(name)
      schemas[name.to_sym]
    end
  end
end
