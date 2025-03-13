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

      # Book Routes
      get 'books/search_suggestions', to: 'books#search_suggestions'
      post 'books/create', to: 'books#create'
      get 'books', to: 'books#index'  
      get 'books/:id', to: 'books#show'
      put 'books/:id', to: 'books#update'
      delete 'books/:id', to: 'books#destroy'
      patch 'books/:id/is_deleted', to: 'books#is_deleted'

      # Cart Routes
      post   'cart/add', to: 'carts#add'         
      patch  'cart/toggle_remove', to: 'carts#toggle_remove' 
      get    'cart', to: 'carts#index'  

       # Review Routes
       post 'books/:book_id/reviews', to: 'reviews#create' 
       get 'books/:book_id/reviews', to: 'reviews#index' 
       get 'books/:book_id/reviews/:id', to: 'reviews#show' 
       delete 'books/:book_id/reviews/:id', to: 'reviews#destroy' 
      
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
      get 'orders', to: 'orders#user_orders'              
      post 'orders', to: 'orders#create'                  
      get 'orders/:id', to: 'orders#show'
      patch 'orders/:id/cancel', to: 'orders#cancel'
      patch 'orders/:id/update_status', to: 'orders#update_status'
    end
  end
end
