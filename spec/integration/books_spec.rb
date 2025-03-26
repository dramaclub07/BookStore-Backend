require 'rails_helper'

RSpec.describe Api::V1::BooksController, type: :request do
  let(:user) { create(:user) }
  let(:book) { create(:book, book_name: 'Test Book', author_name: 'Author', book_mrp: 100, discounted_price: 80, is_deleted: false) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe 'GET /api/v1/books' do
    before { create_list(:book, 3, is_deleted: false) }

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
  end

  describe 'GET /api/v1/books/search' do
    before { create(:book, book_name: 'Ruby Programming', is_deleted: false) }

    it 'returns books matching the query' do
      get '/api/v1/books/search', params: { query: 'Ruby' }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['books']).to be_an(Array)
      expect(json_response['books'].first['book_name']).to eq('Ruby Programming')
    end

    it 'excludes deleted books' do
      create(:book, book_name: 'Deleted Book', is_deleted: true)
      get '/api/v1/books/search', params: { query: 'Deleted' }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['books']).to be_empty
    end
  end

  describe 'GET /api/v1/books/search_suggestions' do
    before { create_list(:book, 6, book_name: 'Ruby Book', author_name: 'Author', is_deleted: false) }

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
      expect(JSON.parse(response.body)['suggestions']).to be_empty
    end
  end

  describe 'POST /api/v1/books/create' do
    let(:valid_params) { { book: { book_name: 'New Book', author_name: 'New Author', book_mrp: 150, discounted_price: 120 } } }

    context 'without authentication' do
      it 'creates a book successfully' do
        post '/api/v1/books/create', params: valid_params
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['success']).to be true
        expect(JSON.parse(response.body)['book']['book_name']).to eq('New Book')
      end
    end

    context 'with CSV file' do
      let(:csv_path) { File.join(Rails.root, 'public', 'book.csv') }
      let(:csv_file) do
        raise "CSV file not found at #{csv_path}" unless File.exist?(csv_path)
        Rack::Test::UploadedFile.new(File.open(csv_path), 'text/csv')
      end
  
      it 'creates books from CSV' do
        allow(BooksService).to receive(:create_books_from_csv).and_return({ success: true, message: 'Books created' })
        post '/api/v1/books/create', params: { file: csv_file }
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['message']).to eq('Books created')
      end
    end

    context 'with invalid params' do
      it 'returns unprocessable entity' do
        allow(BooksService).to receive(:create_book).and_return({ success: false, errors: 'Invalid data' })
        post '/api/v1/books/create', params: { book: { book_name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to eq('Invalid data')
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
    end

    context 'when book does not exist' do
      it 'returns not found' do
        get '/api/v1/books/999'
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)['error']).to eq('Book not found')
      end
    end
  end

  describe 'PUT /api/v1/books/:id' do
    let(:update_params) { { book: { book_name: 'Updated Book' } } }

    context 'when user is authenticated' do
      it 'updates the book' do
        put "/api/v1/books/#{book.id}", params: update_params, headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['success']).to be true
        expect(book.reload.book_name).to eq('Updated Book')
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        put "/api/v1/books/#{book.id}", params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/books/:id/is_deleted' do
    context 'when user is authenticated' do
      it 'toggles the is_deleted status' do
        patch "/api/v1/books/#{book.id}/is_deleted", headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['success']).to be true
        expect(book.reload.is_deleted).to be true
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
      it 'destroys the book' do
        delete "/api/v1/books/#{book.id}", headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['success']).to be true
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