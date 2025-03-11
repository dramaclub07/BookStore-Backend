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
    end
  end
end
