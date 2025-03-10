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


     
    end
  end
end
