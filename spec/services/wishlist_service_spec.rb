require 'rails_helper'

RSpec.describe WishlistService, type: :service do
  let(:user) { create(:user) }
  let(:book1) { create(:book, book_name: "Book 1", author_name: "Author 1", discounted_price: 10.99, book_image: "image1.jpg") }
  let(:book2) { create(:book, book_name: "Book 2", author_name: "Author 2", discounted_price: 15.99, book_image: "image2.jpg") }
  let(:wishlist_service) { described_class.new(user) }

  describe '#fetch_wishlist' do
    # ... your fetch_wishlist tests ...
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
        allow(Wishlist).to receive(:find_by).and_return(wishlist)
        allow(wishlist).to receive(:update).and_return(false)
        allow(wishlist).to receive_message_chain(:errors, :full_messages).and_return(["Update failed"])
        
        result = wishlist_service.toggle_wishlist(book1.id)
        expect(result[:success]).to be false
        expect(result[:message]).to eq("Update failed")
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
        allow(Wishlist).to receive(:create).and_return(
          double(persisted?: false, errors: double(full_messages: ["Creation failed"]))
        )
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