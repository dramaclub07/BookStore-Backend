require 'rails_helper'

RSpec.describe WishlistService, type: :service do
  let(:user) { create(:user) }
  let(:book1) { create(:book, book_name: "Book 1", author_name: "Author 1", discounted_price: 10.99, book_image: "image1.jpg") }
  let(:book2) { create(:book, book_name: "Book 2", author_name: "Author 2", discounted_price: 15.99, book_image: "image2.jpg") }
  let(:wishlist_service) { described_class.new(user) }

  describe '#fetch_wishlist' do
    context 'when wishlist has books' do
      before do
        create(:wishlist, user: user, book: book1, is_deleted: false)
        create(:wishlist, user: user, book: book2, is_deleted: false)
      end

      it 'returns all books in the wishlist with all attributes' do
        result = wishlist_service.fetch_wishlist
        expect(result[:success]).to be true
        expect(result[:wishlist].size).to eq(2)

        first_item = result[:wishlist].find { |item| item[:book_id] == book1.id }
        expect(first_item[:id]).to be_present
        expect(first_item[:book_id]).to eq(book1.id)
        expect(first_item[:user_id]).to eq(user.id)
        expect(first_item[:book_name]).to eq("Book 1")
        expect(first_item[:author_name]).to eq("Author 1")
        expect(first_item[:discounted_price]).to eq(10.99)
        expect(first_item[:book_image]).to eq("image1.jpg")
      end
    end

    context 'when wishlist has soft deleted books' do
      before do
        create(:wishlist, user: user, book: book1, is_deleted: true)
        create(:wishlist, user: user, book: book2, is_deleted: false)
      end

      it 'returns only non-deleted books' do
        result = wishlist_service.fetch_wishlist
        expect(result[:success]).to be true
        expect(result[:wishlist].size).to eq(1)
        expect(result[:wishlist].first[:book_id]).to eq(book2.id)
      end
    end

    context 'when wishlist has books with is_deleted as nil' do
      before do
        create(:wishlist, user: user, book: book1, is_deleted: nil)
        create(:wishlist, user: user, book: book2, is_deleted: true)
      end

      it 'returns books where is_deleted is nil or false' do
        result = wishlist_service.fetch_wishlist
        expect(result[:success]).to be true
        expect(result[:wishlist].size).to eq(1)
        expect(result[:wishlist].first[:book_id]).to eq(book1.id)
      end
    end

    context 'when wishlist is empty' do
      it 'returns an empty array' do
        result = wishlist_service.fetch_wishlist
        expect(result[:success]).to be true
        expect(result[:wishlist]).to be_empty
      end
    end
  end

  describe '#toggle_wishlist' do
    context 'when book is already in wishlist' do
      let!(:wishlist) { create(:wishlist, user: user, book: book1, is_deleted: false) }

      it 'soft deletes the book from wishlist' do
        result = wishlist_service.toggle_wishlist(book1.id)
        wishlist.reload

        expect(wishlist.is_deleted).to be_truthy
        expect(result[:success]).to be true
        expect(result[:message]).to eq('Book removed from wishlist')
      end

      it 're-adds the book to wishlist if already deleted' do
        wishlist.update(is_deleted: true)
        result = wishlist_service.toggle_wishlist(book1.id)
        wishlist.reload

        expect(wishlist.is_deleted).to be_falsy
        expect(result[:success]).to be true
        expect(result[:message]).to eq('Book added back to wishlist')
      end

      it 'handles update failure' do
        allow_any_instance_of(Wishlist).to receive(:update).and_return(false)
        allow_any_instance_of(Wishlist).to receive(:errors).and_return(
          double(full_messages: ["is_deleted update failed"])
        )
        result = wishlist_service.toggle_wishlist(book1.id)
        wishlist.reload

        expect(wishlist.is_deleted).to be_falsy # Unchanged due to failure
        expect(result[:success]).to be false
        expect(result[:message]).to eq("is_deleted update failed")
      end
    end

    context 'when book is not in wishlist' do
      it 'adds the book to the wishlist' do
        result = wishlist_service.toggle_wishlist(book1.id)
        wishlist = Wishlist.find_by(user_id: user.id, book_id: book1.id)

        expect(wishlist).to be_present
        expect(wishlist.is_deleted).to be_falsy
        expect(result[:success]).to be true
        expect(result[:message]).to eq('Book added to wishlist')
      end

      it 'handles creation failure' do
        failed_wishlist = Wishlist.new(user_id: user.id, book_id: book1.id, is_deleted: false)
        failed_wishlist.errors.add(:base, "Creation failed")
        allow(Wishlist).to receive(:create).and_return(failed_wishlist)

        result = wishlist_service.toggle_wishlist(book1.id)

        expect(result[:success]).to be false
        expect(result[:message]).to eq("Creation failed")
      end
    end

    context 'when book_id is invalid' do
      it 'returns an error for invalid book_id' do
        result = wishlist_service.toggle_wishlist(nil)
        expect(result[:success]).to be false
        expect(result[:message]).to eq('Invalid book_id')
      end
    end

    context 'when book is not found or unavailable' do
      let(:unavailable_book) { create(:book, is_deleted: true) }

      it 'returns an error if book is not found or unavailable' do
        result = wishlist_service.toggle_wishlist(unavailable_book.id)
        expect(result[:success]).to be false
        expect(result[:message]).to eq('Book not found or unavailable')
      end
    end
  end
end