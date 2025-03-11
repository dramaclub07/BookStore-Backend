require 'rails_helper'

RSpec.describe WishlistService, type: :service do
  let(:user) { create(:user) }
  let(:book1) { create(:book) }
  let(:book2) { create(:book) }
  let(:wishlist_service) { described_class.new(user) }

  describe '#fetch_wishlist' do
    context 'when wishlist has books' do
      before do
        create(:wishlist, user: user, book: book1, is_deleted: false)
        create(:wishlist, user: user, book: book2, is_deleted: false)
      end

      it 'returns all books in the wishlist' do
        result = wishlist_service.fetch_wishlist
        expect(result.size).to eq(2)
        expect(result.first[:book_id]).to eq(book1.id)
        expect(result.last[:book_id]).to eq(book2.id)
      end
    end

    context 'when wishlist has soft deleted books' do
      before do
        create(:wishlist, user: user, book: book1, is_deleted: true)
        create(:wishlist, user: user, book: book2, is_deleted: false)
      end

      it 'returns only non-deleted books' do
        result = wishlist_service.fetch_wishlist
        expect(result.size).to eq(1)
        expect(result.first[:book_id]).to eq(book2.id)
      end
    end

    context 'when wishlist is empty' do
      it 'returns an empty array' do
        result = wishlist_service.fetch_wishlist
        expect(result).to be_empty
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
        expect(result[:message]).to eq('Book removed from wishlist')
      end

      it 're-adds the book to wishlist if already deleted' do
        wishlist.update(is_deleted: true)
        result = wishlist_service.toggle_wishlist(book1.id)
        wishlist.reload

        expect(wishlist.is_deleted).to be_falsy
        expect(result[:message]).to eq('Book added back to wishlist')
      end
    end

    context 'when book is not in wishlist' do
      it 'adds the book to wishlist' do
        result = wishlist_service.toggle_wishlist(book1.id)
        wishlist = Wishlist.find_by(user_id: user.id, book_id: book1.id)

        expect(wishlist).not_to be_nil
        expect(wishlist.is_deleted).to be_falsy
        expect(result[:message]).to eq('Book added to wishlist')
      end
    end
  end
end
