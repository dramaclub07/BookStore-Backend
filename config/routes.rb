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

       # Review Routes
       post 'books/:book_id/reviews', to: 'reviews#create' # Add a review
       get 'books/:book_id/reviews', to: 'reviews#index' # Get all reviews for a book
       get 'books/:book_id/reviews/:id', to: 'reviews#show' # Get a specific review
       delete 'books/:book_id/reviews/:id', to: 'reviews#destroy' # Delete a review
      
    end
  end
end
