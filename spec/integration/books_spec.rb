require 'rails_helper'

RSpec.describe Api::V1::BooksController, type: :request do
  let(:admin_user) { create(:user, role: 'admin') } # Add admin user for tests requiring admin access
  let(:user) { create(:user) }
  let(:book) { create(:book, book_name: 'Test Book', author_name: 'Author', book_mrp: 100, discounted_price: 80, is_deleted: false, out_of_stock: false) }
  let(:token) { JwtService.encode_access_token(user_id: user.id) } # Fix: Use encode_access_token
  let(:admin_token) { JwtService.encode_access_token(user_id: admin_user.id) } # Token for admin user
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }
  let(:admin_headers) { { 'Authorization' => "Bearer #{admin_token}" } } # Headers for admin user

  describe 'GET /api/v1/books' do
    before { create_list(:book, 5, is_deleted: false, out_of_stock: false) }

    it 'returns a paginated list of books' do
      get '/api/v1/books', params: { page: 1, per_page: 2 }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['books']).to be_an(Array)
      expect(json_response['books'].size).to eq(2)
      expect(json_response['pagination']).to include('current_page', 'total_pages', 'total_count')
    end

    it 'sorts books by relevance by default' do
      get '/api/v1/books'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['books']).to be_present
    end

    it 'returns all books when no pagination params are provided' do
      get '/api/v1/books'
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['books'].size).to eq(5)
    end

    it 'excludes deleted books' do
      create(:book, book_name: 'Deleted Book', is_deleted: true)
      get '/api/v1/books', params: { page: 1, per_page: 10 }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['books'].size).to eq(5)
      expect(json_response['books']).not_to include(hash_including('book_name' => 'Deleted Book'))
    end

    it 'handles invalid page numbers gracefully' do
      get '/api/v1/books', params: { page: -1, per_page: 2 }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['books']).to be_an(Array)
    end
  end

  describe 'GET /api/v1/books/search' do
    before do
      create(:book, book_name: 'Ruby Programming', author_name: 'John Doe', is_deleted: false, out_of_stock: false)
      create(:book, book_name: 'Python Guide', author_name: 'Jane Smith', is_deleted: false, out_of_stock: false)
    end

    it 'returns books matching the query by book_name' do
      get '/api/v1/books/search', params: { query: 'Ruby' }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['books']).to be_an(Array)
      expect(json_response['books'].first['book_name']).to eq('Ruby Programming')
      expect(json_response['books'].size).to eq(1)
    end

    it 'excludes deleted books' do
      create(:book, book_name: 'Deleted Book', is_deleted: true)
      get '/api/v1/books/search', params: { query: 'Deleted' }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['books']).to be_empty
    end

    it 'returns empty array for no matches' do
      get '/api/v1/books/search', params: { query: 'Nonexistent' }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['books']).to be_empty
    end

    it 'returns all books for blank query' do
      get '/api/v1/books/search', params: { query: '' }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['books']).not_to be_empty
      expect(json_response['books'].size).to eq(2)
    end
  end

  describe 'GET /api/v1/books/search_suggestions' do
    before { create_list(:book, 6, book_name: 'Ruby Book', author_name: 'Author', is_deleted: false, out_of_stock: false) }

    it 'returns up to 5 suggestions for a query' do
      get '/api/v1/books/search_suggestions', params: { query: 'Ruby' }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['suggestions'].size).to eq(5)
      expect(json_response['suggestions'].first).to include('id', 'book_name', 'author_name')
    end

    it 'returns empty suggestions for blank query' do
      get '/api/v1/books/search_suggestions', params: { query: '' }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['suggestions']).to be_empty
    end

    it 'returns fewer suggestions if less than 5 matches' do
      Book.where(book_name: 'Ruby Book').destroy_all
      create(:book, book_name: 'Ruby Intro', is_deleted: false, out_of_stock: false)
      get '/api/v1/books/search_suggestions', params: { query: 'Ruby' }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['suggestions'].size).to eq(1)
    end

    it 'excludes deleted books from suggestions' do
      create(:book, book_name: 'Ruby Deleted', is_deleted: true)
      get '/api/v1/books/search_suggestions', params: { query: 'Ruby' }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['suggestions'].size).to eq(5)
      expect(json_response['suggestions']).not_to include(hash_including('book_name' => 'Ruby Deleted'))
    end
  end

  describe 'POST /api/v1/books' do
    let(:valid_params) { { book: { book_name: 'New Book', author_name: 'New Author', book_mrp: 150, discounted_price: 120 } } }

    context 'with admin authentication' do # Fix: Update context to reflect admin authentication requirement
      it 'creates a book successfully' do
        post '/api/v1/books', params: valid_params, headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['book']['book_name']).to eq('New Book')
      end

      it 'fails to create a book with only required fields' do
        post '/api/v1/books', params: { book: { book_name: 'Minimal Book', author_name: 'Minimal Author' } }, headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end

      it 'succeeds with duplicate book name' do
        create(:book, book_name: 'New Book', is_deleted: false, out_of_stock: false)
        post '/api/v1/books', params: valid_params, headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
      end
    end

    context 'with CSV file' do
      let(:csv_content) { "book_name,author_name,book_mrp,discounted_price\nTest CSV Book,CSV Author,200,180" }
      let(:csv_file) { Rack::Test::UploadedFile.new(StringIO.new(csv_content), 'text/csv', original_filename: 'books.csv') }

      it 'creates books from CSV' do
        post '/api/v1/books', params: { file: csv_file }, headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(Book.find_by(book_name: 'Test CSV Book')).to be_present
      end

      it 'handles invalid CSV gracefully' do
        invalid_csv = Rack::Test::UploadedFile.new(StringIO.new("invalid,data"), 'text/csv', original_filename: 'invalid.csv')
        post '/api/v1/books', params: { file: invalid_csv }, headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable entity for missing book_name' do
        post '/api/v1/books', params: { book: { author_name: 'Author' } }, headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Book name can't be blank")
      end

      it 'returns unprocessable entity for negative book_mrp' do
        post '/api/v1/books', params: { book: { book_name: 'Bad Book', author_name: 'Author', book_mrp: -10 } }, headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Book mrp must be greater than 0')
      end
    end

    context 'without authentication' do # Add test for unauthenticated access
      it 'returns unauthorized' do
        post '/api/v1/books', params: valid_params
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Unauthorized - Missing token')
      end
    end

    context 'with non-admin authentication' do # Add test for non-admin user
      it 'returns forbidden' do
        post '/api/v1/books', params: valid_params, headers: headers # Use regular user headers
        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Forbidden - Admin access required')
      end
    end
  end

  describe 'GET /api/v1/books/:id' do
    context 'when book exists' do
      it 'returns book details' do
        get "/api/v1/books/#{book.id}"
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['book_name']).to eq('Test Book')
        expect(json_response['rating']).to eq(0)
        expect(json_response['rating_count']).to eq(0)
      end

      it 'returns deleted book details if is_deleted is true' do
        book.update(is_deleted: true)
        get "/api/v1/books/#{book.id}"
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['book_name']).to eq('Test Book')
      end
    end

    context 'when book does not exist' do
      it 'returns not found' do
        get '/api/v1/books/999'
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Book not found')
      end

      it 'returns not found for invalid ID format' do
        get '/api/v1/books/invalid'
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Book not found')
      end
    end
  end

  describe 'PUT /api/v1/books/:id' do
    let(:update_params) { { book: { book_name: 'Updated Book' } } }

    context 'when user is authenticated' do
      it 'updates the book' do
        put "/api/v1/books/#{book.id}", params: update_params, headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(book.reload.book_name).to eq('Updated Book')
      end

      it 'updates discounted_price without changing other fields' do
        put "/api/v1/books/#{book.id}", params: { book: { discounted_price: 90 } }, headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:ok)
        expect(book.reload.discounted_price).to eq(90)
        expect(book.book_name).to eq('Test Book')
      end

      it 'fails to update with invalid data' do
        put "/api/v1/books/#{book.id}", params: { book: { book_mrp: -5 } }, headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        put "/api/v1/books/#{book.id}", params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when book does not exist' do
      it 'returns not found' do
        put '/api/v1/books/999', params: update_params, headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /api/v1/books/:id/is_deleted' do
    context 'when user is authenticated' do
      it 'toggles is_deleted to true' do
        patch "/api/v1/books/#{book.id}/is_deleted", headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(book.reload.is_deleted).to be true
      end

      it 'toggles is_deleted back to false' do
        book.update(is_deleted: true)
        patch "/api/v1/books/#{book.id}/is_deleted", headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:ok)
        expect(book.reload.is_deleted).to be false
      end

      it 'returns not found for non-existent book' do
        patch '/api/v1/books/999/is_deleted', headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        patch "/api/v1/books/#{book.id}/is_deleted"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/books/:id' do
    context 'when user is authenticated' do
      it 'soft-deletes the book' do
        delete "/api/v1/books/#{book.id}", headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(book.reload.is_deleted).to be true
      end

      it 'returns not found for non-existent book' do
        delete '/api/v1/books/999', headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:not_found)
      end

      it 'handles already deleted book gracefully' do
        book.update(is_deleted: true)
        delete "/api/v1/books/#{book.id}", headers: admin_headers # Fix: Use admin_headers
        expect(response).to have_http_status(:ok)
        expect(book.reload.is_deleted).to be true
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        delete "/api/v1/books/#{book.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end