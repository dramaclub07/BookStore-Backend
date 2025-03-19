# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins 'http://127.0.0.1:5500', 'http://localhost:5500' # Match your frontend origin
      resource '/api/v1/login*', # Restrict to wishlist API routes
        headers: :any,
        methods: [:get, :post, :options], # Ensure OPTIONS is included
        credentials: true # Allow Authorization header with JWT
    end
  end