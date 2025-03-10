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
      post 'books/create', to: 'books#create'
      get 'books', to: 'books#index'
      get 'books/:id', to: 'books#show'
      put 'books/:id', to: 'books#update'
      patch 'books/:id', to: 'books#destroy'
      patch 'books/:id/is_deleted', to: 'books#is_deleted'

      # Address Management Routes
      get 'addresses', to: 'addresses#index'         
      post 'addresses/create', to: 'addresses#create' 
      get 'addresses/:id', to: 'addresses#show'       
      put 'addresses/:id', to: 'addresses#update'     
      patch 'addresses/:id', to: 'addresses#update'   
      delete 'addresses/:id', to: 'addresses#destroy' 
    end
  end
end
