require 'rails_helper'

RSpec.describe "Books API", type: :request do
  let(:user) { create(:user) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:book) { create(:book, is_deleted: false) }

  describe "GET /api/v1/books/:id" do
    context "when the book exists" do
      before { get "/api/v1/books/#{book.id}" }

      it "returns the book" do
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body, symbolize_names: true)

        expect(json_response).to include(
          book_name: book.book_name,
          author_name: book.author_name,
          discounted_price: book.discounted_price.to_s, # Match string response
          book_mrp: book.book_mrp.to_s,                 # Match string response
          book_image: book.book_image,
          description: book.book_details
        )
        expect(json_response[:rating]).to eq(book.reviews.average(:rating)&.round(1) || 0)
        expect(json_response[:rating_count]).to eq(book.reviews.count)
      end
    end

    context "when the book does not exist" do
      before { get "/api/v1/books/9999" }

      it "returns a not found error" do
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)["error"]).to eq("Book not found")
      end
    end
  end

  describe "PUT /api/v1/books/:id" do
    let(:updated_params) { { book: { book_name: "Updated Book Name" } } }

    context "with valid authentication" do
      before do
        put "/api/v1/books/#{book.id}",
            params: updated_params.to_json,
            headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
      end

      it "updates the book" do
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body, symbolize_names: true)
        expect(json_response[:success]).to be true
        expect(json_response[:book][:book_name]).to eq("Updated Book Name")
        expect(book.reload.book_name).to eq("Updated Book Name")
      end
    end

    context "without authentication" do
      before do
        put "/api/v1/books/#{book.id}", params: updated_params.to_json, headers: { "Content-Type" => "application/json" }
      end

      it "returns unauthorized" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/books/:id/is_deleted" do
    context "with valid authentication" do
      before do
        patch "/api/v1/books/#{book.id}/is_deleted",
              headers: { "Authorization" => "Bearer #{token}" }
      end

      it "marks book as deleted" do
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body, symbolize_names: true)
        expect(json_response[:success]).to be true
        expect(json_response[:book][:is_deleted]).to be true
        expect(book.reload.is_deleted).to be true
      end
    end

    context "without authentication" do
      before { patch "/api/v1/books/#{book.id}/is_deleted" }

      it "returns unauthorized" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end