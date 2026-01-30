# frozen_string_literal: true

module OpenapiMinitest
  class Railtie < Rails::Railtie
    railtie_name :openapi_minitest

    rake_tasks do
      namespace :openapi do
        desc "Generate OpenAPI documentation from tests"
        task generate: :environment do
          ENV["OPENAPI_GENERATE"] = "true"

          require "rails/test_unit/runner"
          Rails::TestUnit::Runner.run(ARGV)
        end
      end
    end

    initializer "openapi_minitest.configure" do
      ActiveSupport.on_load(:action_dispatch_integration_test) do
        include OpenapiMinitest::DSL
      end
    end

    config.after_initialize do
      if Rails.env.test?
        Minitest.after_run do
          if ENV["OPENAPI_GENERATE"] == "true" && !OpenapiMinitest::ResultCollector.instance.empty?
            path = OpenapiMinitest::OpenAPI::Generator.new.write
            puts "\nOpenAPI documentation generated: #{path}"
          end
        end
      end
    end
  end
end
