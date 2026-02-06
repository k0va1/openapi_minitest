# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

openapi_minitest is a Ruby gem that generates OpenAPI 3.1.0 documentation from Minitest integration tests. Users call a single `document_response` helper method in their tests to capture API endpoints into an OpenAPI YAML file.

## Commands

- **Run all tests + lint:** `bundle exec rake` (default task runs both `test` and `standard`)
- **Run tests only:** `bundle exec rake test`
- **Run a single test:** `bundle exec ruby -Ilib:test test/test_openapi_minitest.rb -n test_method_name`
- **Lint:** `bundle exec rake standard`
- **Lint autofix:** `bundle exec standardrb --fix`

## Architecture

The generation pipeline flows through four components in order:

1. **DSL (`lib/openapi_minitest/dsl.rb`)** — Provides the `document_response` method mixed into test classes. Handles schema validation (optional) and normalization of Symbol schema references to `$ref` format.

2. **ResultCollector (`lib/openapi_minitest/result_collector.rb`)** — Singleton that accumulates all recorded API calls during a test run. Stores two parallel hashes keyed by `"method /path"`: `@operations` (endpoint metadata) and `@responses` (grouped by HTTP status). Handles path normalization (e.g., `/api/users/123` → `/api/users/{user_id}`).

3. **Generator (`lib/openapi_minitest/openapi/generator.rb`)** — Reads from ResultCollector and builds the complete OpenAPI 3.1.0 document hash. Handles path sorting, request body extraction, example merging, and security scheme attachment. Outputs YAML.

4. **Railtie (`lib/openapi_minitest/railtie.rb`)** — Rails integration. Auto-includes DSL in `ActionDispatch::IntegrationTest`, registers `rails openapi:generate` rake task, and hooks into `Minitest.after_run` to trigger generation when `OPENAPI_GENERATE=true`.

Configuration and schema registry live in `lib/openapi_minitest/configuration.rb`.

## Test Setup

Tests use `OpenapiMinitest::TestHelpers` (defined in `test/test_helper.rb`) which resets both configuration and the ResultCollector singleton in `setup`, ensuring test isolation.

## Conventions

- Use Conventional Commits format for all commit messages (e.g., `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`)
