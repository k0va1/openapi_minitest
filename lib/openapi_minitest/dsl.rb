# frozen_string_literal: true

require "json"
require "json-schema"

module OpenapiMinitest
  module DSL
    # Records the current request/response for OpenAPI documentation.
    #
    # Call this after making a request and asserting the response status.
    # It captures all the details needed for OpenAPI generation.
    #
    # @param schema [Symbol, Hash, nil] Schema name (references defined schema) or inline schema hash
    # @param summary [String, nil] Short summary of the operation (defaults to test name)
    # @param description [String, nil] Description of this specific response
    # @param tags [Array<String>] Tags for grouping endpoints
    # @param operation_id [String, nil] Unique operation identifier
    # @param deprecated [Boolean] Whether this endpoint is deprecated
    #
    # @example Basic usage
    #   def test_returns_users
    #     get "/api/users"
    #     assert_response 200
    #     document_response schema: :UserList, description: "Returns all users"
    #   end
    #
    # @example With tags and summary
    #   def test_creates_user
    #     post "/api/users", params: { name: "John" }
    #     assert_response 201
    #     document_response schema: :User, summary: "Create user", tags: ["Users"]
    #   end
    #
    # @example Inline schema
    #   def test_health_check
    #     get "/health"
    #     assert_response 200
    #     document_response schema: { type: :object, properties: { status: { type: :string } } }
    #   end
    #
    # @example Without schema (just documents the endpoint)
    #   def test_deletes_user
    #     delete "/api/users/1"
    #     assert_response 204
    #     document_response description: "User deleted"
    #   end
    #
    def document_response(schema: nil, summary: nil, description: nil, tags: [], operation_id: nil, deprecated: false)
      # Validate schema if provided and validation is enabled
      if schema && OpenapiMinitest.configuration.validate_schema && response.body.present?
        validate_response_schema!(schema)
      end

      # Record for OpenAPI generation
      ResultCollector.instance.record(
        request: request,
        response: response,
        schema: normalize_schema(schema),
        summary: summary || generate_summary,
        description: description,
        tags: Array(tags),
        operation_id: operation_id,
        deprecated: deprecated,
        test_name: name
      )
    end

    private

    def validate_response_schema!(schema)
      resolved = resolve_schema(schema)
      body = JSON.parse(response.body)

      errors = JSON::Validator.fully_validate(
        stringify_keys(resolved),
        body,
        strict: false,
        clear_cache: true
      )

      return if errors.empty?

      flunk "Response does not match schema:\n#{errors.join("\n")}\n\nBody: #{response.body}"
    rescue JSON::ParserError => e
      flunk "Response is not valid JSON: #{e.message}"
    end

    def resolve_schema(schema)
      case schema
      when Symbol
        referenced = OpenapiMinitest.schema(schema)
        raise ArgumentError, "Unknown schema: #{schema}" unless referenced
        deep_resolve_refs(deep_dup(referenced))
      when Hash
        deep_resolve_refs(deep_dup(schema))
      else
        schema
      end
    end

    def deep_resolve_refs(obj)
      case obj
      when Hash
        if obj[:$ref] || obj["$ref"]
          ref = obj[:$ref] || obj["$ref"]
          if ref.to_s.start_with?("#/components/schemas/")
            schema_name = ref.to_s.split("/").last.to_sym
            referenced = OpenapiMinitest.schema(schema_name)
            if referenced
              return deep_resolve_refs(deep_dup(referenced))
            end
          end
        end
        obj.transform_values { |v| deep_resolve_refs(v) }
      when Array
        obj.map { |item| deep_resolve_refs(item) }
      else
        obj
      end
    end

    def deep_dup(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
      when Array
        obj.map { |item| deep_dup(item) }
      else
        obj
      end
    end

    def stringify_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(key, value), result|
          result[key.to_s] = stringify_keys(value)
        end
      when Array
        obj.map { |item| stringify_keys(item) }
      else
        obj
      end
    end

    def normalize_schema(schema)
      case schema
      when Symbol
        {"$ref" => "#/components/schemas/#{schema}"}
      when Hash
        stringify_keys(schema)
      end
    end

    def generate_summary
      # Convert test_creates_user -> "Creates user"
      name.to_s
        .sub(/^test_/, "")
        .tr("_", " ")
        .capitalize
    end
  end
end
