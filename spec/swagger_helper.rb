# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Use openapi_root instead of deprecated swagger_root
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define OpenAPI documents with global metadata
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Bookstore API',
        version: 'v1'
      },
      paths: {},
      servers: [
        {
          url: 'http://{defaultHost}',
          variables: {
            defaultHost: {
              default: 'localhost:3000'
            }
          }
        }
      ],
      components: {
        schemas: {}
      }
    }
  }

  # Use openapi_format instead of deprecated swagger_format
  config.openapi_format = :yaml
end
