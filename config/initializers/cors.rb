# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://127.0.0.1:5500', 'http://localhost:5500' 
    resource '*',
    headers: :any,
    methods: [:get, :post, :put, :patch, :delete, :options], 
    credentials: true 
  end
end