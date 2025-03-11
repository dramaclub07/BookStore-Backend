Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  namespace :api do
    namespace :v1 do 
      # User Authentication Routes
      post 'signup', to: 'users#signup'
      post 'login', to: 'users#login'
      post 'forgot_password', to: 'users#forgot_password'
      post 'reset_password', to: 'users#reset_password'

      # Book Routes (Consistent with Authentication Style)
       # Search & Suggestions
      get 'books/search_suggestions', to: 'books#search_suggestions'

      post 'books/create', to: 'books#create'
      get 'books', to: 'books#index'  # Supports pagination (e.g., ?page=1&per_page=10)
      get 'books/:id', to: 'books#show'
      put 'books/:id', to: 'books#update'
      patch 'books/:id', to: 'books#destroy'
      patch 'books/:id/is_deleted', to: 'books#is_deleted'

      # Wishlist Routes 
      get 'wishlists/fetch', to: 'wishlists#index'
      post 'wishlists/toggle/:book_id', to: 'wishlists#toggle'
      # Address Management Routes
      get 'addresses', to: 'addresses#index'         
      post 'addresses/create', to: 'addresses#create' 
      get 'addresses/:id', to: 'addresses#show'       
      put 'addresses/:id', to: 'addresses#update'     
      patch 'addresses/:id', to: 'addresses#update'   
      delete 'addresses/:id', to: 'addresses#destroy'
      
      # Order Management Routes (Only for Logged-in Users)
      get 'orders', to: 'orders#user_orders'              # Get all orders for logged-in user
      post 'orders', to: 'orders#create'                  # Create an order
      get 'orders/:id', to: 'orders#show'                 # Get details of a specific order
      patch 'orders/:id/cancel', to: 'orders#cancel'      # Cancel an order
      patch 'orders/:id/update_status', to: 'orders#update_status'  # Update order status
    end
  end
end
