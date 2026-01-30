# frozen_string_literal: true

require "json"
require "fileutils"

module OpenapiMinitest
  module OpenAPI
    class Generator
      def initialize
        @config = OpenapiMinitest.configuration
        @collector = ResultCollector.instance
      end

      def generate
        {
          "openapi" => "3.1.0",
          "info" => build_info,
          "servers" => build_servers,
          "paths" => build_paths,
          "components" => build_components
        }.compact
      end

      def write
        path = @config.output_path
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, JSON.pretty_generate(generate))
        path
      end

      private

      def build_info
        info = {
          "title" => @config.title,
          "version" => @config.version
        }
        info["description"] = @config.description if @config.description
        info
      end

      def build_servers
        return nil if @config.servers.empty?

        @config.servers.map do |server|
          case server
          when String
            {"url" => server}
          when Hash
            stringify_keys(server)
          end
        end
      end

      def build_paths
        paths = {}

        @collector.operations.each do |key, operation|
          path = operation[:path]
          method = operation[:method]

          paths[path] ||= {}
          paths[path][method] = build_operation(key, operation)
        end

        paths
      end

      def build_operation(key, operation)
        op = {}

        op["summary"] = operation[:summary] if operation[:summary]
        op["tags"] = operation[:tags] if operation[:tags]&.any?
        op["operationId"] = operation[:operation_id] if operation[:operation_id]
        op["deprecated"] = true if operation[:deprecated]

        # Parameters
        if operation[:parameters]&.any?
          op["parameters"] = operation[:parameters].map { |p| stringify_keys(p) }
        end

        # Request body (for POST/PUT/PATCH)
        request_body = build_request_body(key, operation[:method])
        op["requestBody"] = request_body if request_body

        # Responses
        op["responses"] = build_responses(key)

        op
      end

      def build_request_body(key, method)
        return nil unless %w[post put patch].include?(method)

        responses = @collector.responses[key]
        return nil unless responses

        # Find a request example from any response
        example = nil
        responses.each_value do |response_list|
          response_list.each do |resp|
            if resp[:request_example]
              example = resp[:request_example]
              break
            end
          end
          break if example
        end

        return nil unless example

        {
          "required" => true,
          "content" => {
            "application/json" => {
              "schema" => {"type" => "object"},
              "example" => example
            }
          }
        }
      end

      def build_responses(key)
        responses_data = @collector.responses[key] || {}
        responses = {}

        responses_data.each do |status, response_list|
          primary = response_list.first

          response = {
            "description" => primary[:description]
          }

          # Add content with schema and examples
          if primary[:schema] || primary[:example]
            content = {}

            content["schema"] = primary[:schema] if primary[:schema]

            # Build examples from all responses with this status
            if response_list.any? { |r| r[:example] }
              examples = {}
              response_list.each do |resp|
                next unless resp[:example]
                example_name = resp[:test_name] || "example"
                examples[example_name] = {
                  "value" => resp[:example]
                }
              end
              content["examples"] = examples if examples.any?
            end

            response["content"] = {
              "application/json" => content
            }
          end

          responses[status] = response
        end

        # Ensure at least one response
        responses["200"] = {"description" => "Successful response"} if responses.empty?

        responses
      end

      def build_components
        components = {}

        # Add registered schemas
        if OpenapiMinitest.schemas.any?
          components["schemas"] = {}
          OpenapiMinitest.schemas.each do |name, schema|
            components["schemas"][name.to_s] = stringify_keys(schema)
          end
        end

        # Add security schemes
        if @config.security_schemes.any?
          components["securitySchemes"] = stringify_keys(@config.security_schemes)
        end

        components.empty? ? nil : components
      end

      def stringify_keys(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(key, value), result|
            result[key.to_s] = stringify_keys(value)
          end
        when Array
          obj.map { |item| stringify_keys(item) }
        when Symbol
          obj.to_s
        else
          obj
        end
      end
    end
  end
end
