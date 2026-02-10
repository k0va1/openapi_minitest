# frozen_string_literal: true

module OpenapiMinitest
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Generates an ApiDocsController and view for serving OpenAPI documentation with Scalar UI"

      def copy_controller
        template "api_docs_controller.rb.tt", "app/controllers/api_docs_controller.rb"
      end

      def copy_view
        template "index.html.erb.tt", "app/views/api_docs/index.html.erb"
      end

      def add_routes
        route <<~RUBY
          get "api-docs" => "api_docs#index"
          get "openapi.yml" => "api_docs#spec"
        RUBY
      end

      private

      def app_name
        Rails.application.class.respond_to?(:module_parent_name) ? Rails.application.class.module_parent_name : Rails.application.class.parent_name
      end
    end
  end
end
