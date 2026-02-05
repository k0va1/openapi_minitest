# frozen_string_literal: true

require "singleton"
require "json"

module OpenapiMinitest
  class ResultCollector
    include Singleton

    def initialize
      reset!
    end

    def reset!
      @operations = {}  # "METHOD /path" => operation data
      @responses = {}   # "METHOD /path" => { status => [response_data] }
    end

    def record(request:, response:, schema:, summary:, description:, tags:, operation_id:, deprecated:, test_name:)
      method = request.request_method.downcase
      path = normalize_path(request.path)
      key = "#{method} #{path}"

      # Store operation metadata (first one wins for summary, tags merge)
      @operations[key] ||= {
        method: method,
        path: path,
        summary: summary,
        tags: [],
        operation_id: operation_id,
        deprecated: deprecated,
        parameters: extract_parameters(request, path),
        requires_auth: has_authorization_header?(request)
      }

      # Merge tags from all tests
      @operations[key][:tags] = (@operations[key][:tags] + tags).uniq

      # Store response data grouped by status
      status = response.status.to_s
      @responses[key] ||= {}
      @responses[key][status] ||= []

      @responses[key][status] << {
        description: description || default_description(response.status),
        schema: schema,
        example: parse_body(response.body),
        test_name: test_name,
        request_example: extract_request_example(request)
      }
    end

    attr_reader :operations

    attr_reader :responses

    def empty?
      @operations.empty?
    end

    private

    def normalize_path(path)
      # Convert /api/users/123 to /api/users/{id}
      # Convert /api/users/123/posts/456 to /api/users/{id}/posts/{post_id}
      segments = path.split("/")
      normalized = []
      param_counts = Hash.new(0)

      segments.each_with_index do |segment, index|
        if segment.match?(/^\d+$/)
          # This is an ID - figure out what to call it
          prev_segment = segments[index - 1]
          if prev_segment
            # Singularize: users -> user_id, posts -> post_id
            param_name = singularize(prev_segment) + "_id"
            # Handle multiple params of same type
            if param_counts[param_name] > 0
              param_name = "#{param_name}_#{param_counts[param_name] + 1}"
            end
            param_counts[param_name] += 1
            # First occurrence of a resource ID is just {id} for cleaner paths
            param_name = "id" if param_counts[param_name] == 1 && normalized.size == segments.size - 2
            normalized << "{#{param_name}}"
          else
            normalized << "{id}"
          end
        else
          normalized << segment
        end
      end

      normalized.join("/")
    end

    def singularize(word)
      # Basic singularization - in Rails app, would use ActiveSupport
      if word.end_with?("ies")
        word[0..-4] + "y"
      elsif word.end_with?("ses", "xes", "zes", "ches", "shes")
        word[0..-3]
      elsif word.end_with?("s") && !word.end_with?("ss")
        word[0..-2]
      else
        word
      end
    end

    def extract_parameters(request, normalized_path)
      params = []

      # Path parameters
      normalized_path.scan(/\{(\w+)\}/).flatten.each do |param_name|
        params << {
          name: param_name,
          in: "path",
          required: true,
          schema: {type: "string"}
        }
      end

      # Query parameters
      if request.query_parameters.any?
        request.query_parameters.each do |name, value|
          params << {
            name: name.to_s,
            in: "query",
            required: false,
            schema: infer_schema_type(value)
          }
        end
      end

      # Note: Authorization header is handled via security schemes, not parameters

      params
    end

    def has_authorization_header?(request)
      !!(request.headers["Authorization"] || request.headers["HTTP_AUTHORIZATION"])
    end

    def infer_schema_type(value)
      case value
      when Integer then {type: "integer"}
      when Float then {type: "number"}
      when TrueClass, FalseClass then {type: "boolean"}
      when Array then {type: "array", items: {type: "string"}}
      else {type: "string"}
      end
    end

    def extract_request_example(request)
      return nil if request.request_method == "GET"

      body = request.body.read
      request.body.rewind
      return nil if body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    def parse_body(body)
      return nil if body.nil? || body.empty?
      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    def default_description(status)
      {
        200 => "Successful response",
        201 => "Created",
        204 => "No content",
        400 => "Bad request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not found",
        422 => "Unprocessable entity",
        500 => "Internal server error"
      }[status] || "Response"
    end
  end
end
