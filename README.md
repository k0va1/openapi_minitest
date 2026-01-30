# OpenapiMinitest

Generate OpenAPI 3.0 documentation from your Minitest integration tests. No DSL, no magic - just one helper method.

## Installation

Add to your Gemfile:

```ruby
gem "openapi_minitest"
```

Then run:

```bash
bundle install
```

## Quick Start

### 1. Configure (optional)

```ruby
# config/initializers/openapi_minitest.rb (Rails)
# or test/support/openapi.rb

OpenapiMinitest.configure do |config|
  config.title = "My API"
  config.version = "1.0.0"
  config.description = "API documentation"
  config.output_path = "doc/openapi.json"
  config.servers = ["https://api.example.com"]
end
```

### 2. Define Schemas

```ruby
OpenapiMinitest.define_schema :User, {
  type: :object,
  properties: {
    id: { type: :integer },
    email: { type: :string, format: :email },
    name: { type: :string }
  },
  required: %w[id email]
}

OpenapiMinitest.define_schema :UserList, {
  type: :object,
  properties: {
    data: { type: :array, items: { "$ref" => "#/components/schemas/User" } },
    meta: {
      type: :object,
      properties: {
        total: { type: :integer },
        page: { type: :integer }
      }
    }
  }
}

OpenapiMinitest.define_schema :Error, {
  type: :object,
  properties: {
    error: { type: :string },
    code: { type: :integer }
  }
}
```

### 3. Write Tests

Write normal Minitest tests. Call `document_response` after each request you want documented:

```ruby
class UsersApiTest < ActionDispatch::IntegrationTest
  def test_returns_users
    create(:user, name: "John")
    create(:user, name: "Jane")

    get "/api/users", headers: auth_headers

    assert_response 200
    document_response schema: :UserList, description: "Returns all users"

    body = JSON.parse(response.body)
    assert_equal 2, body["data"].size
  end

  def test_filters_users_by_name
    create(:user, name: "John")
    create(:user, name: "Jane")

    get "/api/users", params: { q: "John" }, headers: auth_headers

    assert_response 200
    document_response schema: :UserList, description: "Filters users by name"

    body = JSON.parse(response.body)
    assert_equal 1, body["data"].size
  end

  def test_returns_single_user
    user = create(:user, name: "John")

    get "/api/users/#{user.id}", headers: auth_headers

    assert_response 200
    document_response schema: :User, description: "User found", tags: ["Users"]
  end

  def test_user_not_found
    get "/api/users/999999", headers: auth_headers

    assert_response 404
    document_response schema: :Error, description: "User not found"
  end

  def test_creates_user
    post "/api/users",
      params: { user: { name: "New User", email: "new@example.com" } },
      headers: auth_headers,
      as: :json

    assert_response 201
    document_response schema: :User, description: "User created", tags: ["Users"]
  end

  def test_create_user_validation_error
    post "/api/users",
      params: { user: { name: "" } },
      headers: auth_headers,
      as: :json

    assert_response 422
    document_response schema: :Error, description: "Validation failed"
  end

  private

  def auth_headers
    { "Authorization" => "Bearer #{generate_token}" }
  end
end
```

### 4. Generate Documentation

```bash
# Run tests with documentation generation
OPENAPI_GENERATE=true rails test test/integration/

# Or use the rake task
rails openapi:generate
```

## API Reference

### Configuration Options

```ruby
OpenapiMinitest.configure do |config|
  config.title = "My API"              # API title
  config.version = "1.0.0"             # API version
  config.description = "Description"   # API description
  config.output_path = "doc/api.json"  # Output file path
  config.servers = [                   # Server URLs
    "https://api.example.com",
    { url: "https://staging.example.com", description: "Staging" }
  ]
  config.security_schemes = {          # Security schemes
    bearer: {
      type: :http,
      scheme: :bearer
    }
  }
  config.validate_schema = true        # Validate responses against schemas
end
```

### document_response

Call after making a request to record it for documentation:

```ruby
document_response(
  schema: :SchemaName,          # Schema reference (Symbol) or inline schema (Hash)
  summary: "Operation summary", # Defaults to test name
  description: "Response desc", # Description of this response
  tags: ["Tag1", "Tag2"],       # Tags for grouping
  operation_id: "getUsers",     # Unique operation ID
  deprecated: false             # Mark endpoint as deprecated
)
```

### Schema Definition

```ruby
# Reference to another schema
OpenapiMinitest.define_schema :UserList, {
  type: :object,
  properties: {
    data: { type: :array, items: { "$ref" => "#/components/schemas/User" } }
  }
}

# Inline schema in tests
document_response schema: {
  type: :object,
  properties: {
    status: { type: :string }
  }
}
```

## Features

- **No DSL** - Just one helper method, write normal Minitest tests
- **Schema validation** - Optionally validate responses against schemas during tests
- **Auto-detection** - Automatically extracts path parameters, query params, headers
- **Multiple examples** - Each test becomes an example in the docs
- **Request bodies** - Captures POST/PUT/PATCH request bodies as examples

## How It Works

1. You write normal integration tests
2. Call `document_response` after requests you want documented
3. The gem captures:
   - Request method, path, parameters, headers
   - Response status, body
   - Schema reference or definition
4. After tests run, generates OpenAPI 3.0 JSON

## Path Parameter Detection

The gem automatically detects numeric IDs in paths and converts them:

```
/api/users/123           -> /api/users/{user_id}
/api/users/123/posts/456 -> /api/users/{user_id}/posts/{post_id}
```

## Non-Rails Usage

Include the DSL module manually:

```ruby
class MyApiTest < Minitest::Test
  include OpenapiMinitest::DSL

  # ... your tests
end

# Generate documentation after tests
Minitest.after_run do
  if ENV["OPENAPI_GENERATE"]
    OpenapiMinitest::OpenAPI::Generator.new.write
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/k0va1/openapi_minitest.

## License

MIT
