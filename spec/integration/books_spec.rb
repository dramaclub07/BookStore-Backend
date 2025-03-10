require 'rails_helper'

RSpec.describe 'Books API', type: :request do
  let!(:books) { create_list(:book, 5) }
  let(:book_id) { books.first.id }

  describe 'GET /api/v1/books' do
    it 'returns all books' do
      get '/api/v1/books'
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET /api/v1/books/:id' do
    it 'returns the book' do
      get "/api/v1/books/#{book_id}"
      expect(response).to have_http_status(200)
    end
  end

  describe 'POST /api/v1/books/create' do
    let(:valid_attributes) do
      {
        book_name: 'New Book',
        author_name: 'John Doe',
        book_mrp: 20.5,
        discounted_price: 15.0,
        quantity: 10,
        book_details: 'A great book',
        genre: 'Fiction',
        book_image: 'image_url',
        is_deleted: false
      }
    end

    it 'creates a new book' do
      post '/api/v1/books/create', params: valid_attributes, as: :json
      expect(response).to have_http_status(201)
    end
  end

  describe 'PUT /api/v1/books/:id' do
    let(:updated_attributes) do
      {
        book_name: 'Updated Book',
        author_name: 'Updated Author',
        book_mrp: 25.0,
        discounted_price: 18.0,
        quantity: 5,
        book_details: 'Updated book details',
        genre: 'Non-fiction',
        book_image: 'updated_image_url',
        is_deleted: false
      }
    end

    it 'updates the book' do
      put "/api/v1/books/#{book_id}", params: updated_attributes, as: :json
      expect(response).to have_http_status(200)
    end
  end

  describe 'PATCH /api/v1/books/:id/is_deleted' do
    it 'marks book as deleted' do
      patch "/api/v1/books/#{book_id}/is_deleted", as: :json
      expect(response).to have_http_status(200)
    end
  end
end
