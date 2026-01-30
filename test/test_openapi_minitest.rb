# frozen_string_literal: true

require "test_helper"

class TestOpenapiMinitest < Minitest::Test
  include OpenapiMinitest::TestHelpers

  def test_version
    refute_nil OpenapiMinitest::VERSION
  end

  def test_configure
    OpenapiMinitest.configure do |config|
      config.title = "Test API"
      config.version = "2.0.0"
      config.output_path = "custom/path.json"
    end

    assert_equal "Test API", OpenapiMinitest.configuration.title
    assert_equal "2.0.0", OpenapiMinitest.configuration.version
    assert_equal "custom/path.json", OpenapiMinitest.configuration.output_path
  end

  def test_define_schema
    OpenapiMinitest.define_schema :User, {
      type: :object,
      properties: {
        id: {type: :integer},
        name: {type: :string}
      }
    }

    schema = OpenapiMinitest.schema(:User)
    assert_equal :object, schema[:type]
    assert_equal :integer, schema[:properties][:id][:type]
  end

  def test_reset_clears_schemas
    OpenapiMinitest.define_schema :Test, {type: :object}
    assert OpenapiMinitest.schema(:Test)

    OpenapiMinitest.reset!

    assert_nil OpenapiMinitest.schema(:Test)
  end
end

class TestResultCollector < Minitest::Test
  include OpenapiMinitest::TestHelpers

  def test_singleton
    collector1 = OpenapiMinitest::ResultCollector.instance
    collector2 = OpenapiMinitest::ResultCollector.instance
    assert_same collector1, collector2
  end

  def test_initially_empty
    assert OpenapiMinitest::ResultCollector.instance.empty?
  end

  def test_normalize_path_with_ids
    collector = OpenapiMinitest::ResultCollector.instance

    # Use send to access private method
    result = collector.send(:normalize_path, "/api/users/123")
    assert_equal "/api/users/{user_id}", result
  end

  def test_normalize_path_with_multiple_ids
    collector = OpenapiMinitest::ResultCollector.instance

    result = collector.send(:normalize_path, "/api/users/123/posts/456")
    assert_equal "/api/users/{user_id}/posts/{post_id}", result
  end

  def test_singularize
    collector = OpenapiMinitest::ResultCollector.instance

    assert_equal "user", collector.send(:singularize, "users")
    assert_equal "post", collector.send(:singularize, "posts")
    assert_equal "category", collector.send(:singularize, "categories")
    assert_equal "address", collector.send(:singularize, "addresses")
  end
end

class TestGenerator < Minitest::Test
  include OpenapiMinitest::TestHelpers

  def test_generates_basic_document
    generator = OpenapiMinitest::OpenAPI::Generator.new
    doc = generator.generate

    assert_equal "3.1.0", doc["openapi"]
    assert_equal "API Documentation", doc["info"]["title"]
    assert_equal "1.0.0", doc["info"]["version"]
  end

  def test_generates_with_custom_config
    OpenapiMinitest.configure do |config|
      config.title = "My API"
      config.version = "2.0.0"
      config.description = "API description"
      config.servers = ["https://api.example.com"]
    end

    generator = OpenapiMinitest::OpenAPI::Generator.new
    doc = generator.generate

    assert_equal "My API", doc["info"]["title"]
    assert_equal "2.0.0", doc["info"]["version"]
    assert_equal "API description", doc["info"]["description"]
    assert_equal [{"url" => "https://api.example.com"}], doc["servers"]
  end

  def test_includes_defined_schemas
    OpenapiMinitest.define_schema :User, {
      type: :object,
      properties: {
        id: {type: :integer}
      }
    }

    generator = OpenapiMinitest::OpenAPI::Generator.new
    doc = generator.generate

    assert doc["components"]
    assert doc["components"]["schemas"]
    assert doc["components"]["schemas"]["User"]
    assert_equal "object", doc["components"]["schemas"]["User"]["type"]
  end

  def test_includes_response_examples
    OpenapiMinitest.define_schema :User, {type: :object}

    # Simulate what ResultCollector.record does
    collector = OpenapiMinitest::ResultCollector.instance

    # Manually add a recorded response with example body
    collector.instance_variable_get(:@operations)["get /api/users"] = {
      method: "get",
      path: "/api/users",
      summary: "List users",
      tags: ["Users"],
      operation_id: nil,
      deprecated: false,
      parameters: []
    }

    collector.instance_variable_get(:@responses)["get /api/users"] = {
      "200" => [
        {
          description: "Users found",
          schema: {"$ref" => "#/components/schemas/User"},
          example: {"data" => [{"id" => 1, "name" => "John"}, {"id" => 2, "name" => "Jane"}]},
          test_name: "test_returns_users",
          request_example: nil
        },
        {
          description: "Filtered users",
          schema: {"$ref" => "#/components/schemas/User"},
          example: {"data" => [{"id" => 1, "name" => "John"}]},
          test_name: "test_filters_users",
          request_example: nil
        }
      ]
    }

    generator = OpenapiMinitest::OpenAPI::Generator.new
    doc = generator.generate

    # Check that examples are included
    response_content = doc["paths"]["/api/users"]["get"]["responses"]["200"]["content"]["application/json"]

    assert response_content["examples"], "Expected examples to be present"
    assert response_content["examples"]["test_returns_users"]
    assert response_content["examples"]["test_filters_users"]

    # Check example values contain the actual response data
    assert_equal(
      {"data" => [{"id" => 1, "name" => "John"}, {"id" => 2, "name" => "Jane"}]},
      response_content["examples"]["test_returns_users"]["value"]
    )
    assert_equal(
      {"data" => [{"id" => 1, "name" => "John"}]},
      response_content["examples"]["test_filters_users"]["value"]
    )
  end
end
