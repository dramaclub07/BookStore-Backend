Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  namespace :api do
    namespace :v1 do
      post 'users', to: 'users#create'
      post 'users/login', to: 'users#login'
      post 'users/password/forgot', to: 'users#forgot_password'
      post 'users/password/reset', to: 'users#reset_password'
      get 'users/profile', to: 'users#profile'
      patch 'users/profile', to: 'users#profile'
      put 'user/profile', to: 'users#update_profile'  # Update user profile

      post 'google_auth', to: 'google_auth#create'
      post 'facebook_auth', to: 'facebook_auth#create'

      post 'books', to: 'books#create'
      get 'books/search', to: 'books#search'
      get 'books/search_suggestions', to: 'books#search_suggestions'
      get 'books', to: 'books#index'
      get 'books/available', to: 'books#available'  #new route, accept chnages in controller and service, katoch make out of stock now 
      get 'books/:id', to: 'books#show'
      put 'books/:id', to: 'books#update'
      delete 'books/:id', to: 'books#destroy'
      patch 'books/:id/is_deleted', to: 'books#is_deleted'
  
 
      get 'carts', to: 'carts#index'                   
      post 'carts/:id', to: 'carts#add'                
      patch 'carts/:id', to: 'carts#update_quantity'   
      patch 'carts/:id/delete', to: 'carts#toggle_remove' 
      get 'carts/summary', to: 'carts#summary'         

      post 'books/:book_id/reviews', to: 'reviews#create' 
      get 'books/:book_id/reviews', to: 'reviews#index' 
      get 'books/:book_id/reviews/:id', to: 'reviews#show' 
      delete 'books/:book_id/reviews/:id', to: 'reviews#destroy' 
      
      get 'wishlists', to: 'wishlists#index'
      post 'wishlists', to: 'wishlists#toggle'
      
      get 'addresses', to: 'addresses#index'         
      post 'addresses/create', to: 'addresses#create' 
      get 'addresses/:id', to: 'addresses#show'       
      patch 'addresses/:id', to: 'addresses#update'   
      delete 'addresses/:id', to: 'addresses#destroy'
      
      # Order Management Routes (Only for Logged-in Users)
      get 'orders', to: 'orders#user_orders'              
      post 'orders', to: 'orders#create'                  
      get 'orders/:id', to: 'orders#show'
      patch 'orders/:id/cancel', to: 'orders#cancel'
      patch 'orders/:id/update_status', to: 'orders#update_status'
    end
  end
end