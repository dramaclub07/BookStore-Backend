# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://book-store-frontend-beige-six.vercel.app/','http://127.0.0.1:5500'  # Allow all origins (For development only)

    resource '*',
      headers: :any,
      expose: ['Authorization'],
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
 