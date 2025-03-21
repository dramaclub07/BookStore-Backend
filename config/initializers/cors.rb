Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # Change to your frontend URL if necessary
    resource '*', headers: :any, methods: [:get, :post, :patch, :put, :delete, :options]
  end
end
