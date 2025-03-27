require 'rails_helper'

RSpec.describe cartsService, type: :service do
  let(:user) { create(:user) }
  let(:book) { create(:book, quantity: 10, discounted_price: 200) }
  let(:carts_service) { described_class.new(user) }

  describe "#add_to_carts" do
    context "when adding a valid book with sufficient stock" do
      it "adds the book to the carts successfully" do
        result = carts_service.add_to_carts(book.id, 2)
        expect(result[:success]).to be_truthy
        expect(result[:message]).to eq("Item added to carts.")
        expect(user.cartss.find_by(book: book).quantity).to eq(2)
      end
    end

    context "when book ID is invalid" do
      it "returns an error message" do
        result = carts_service.add_to_carts(9999, 2)
        expect(result[:success]).to be_falsey
        expect(result[:message]).to eq("Book not found or unavailable.")
      end
    end

    context "when quantity is invalid" do
      it "rejects zero or negative quantities" do
        result = carts_service.add_to_carts(book.id, 0)
        expect(result[:success]).to be_falsey
        expect(result[:message]).to eq("Invalid quantity.")
      end
    end

    context "when stock is insufficient" do
      it "prevents adding more than available stock" do
        result = carts_service.add_to_carts(book.id, 11)
        expect(result[:success]).to be_falsey
        expect(result[:message]).to eq("Not enough stock available.")
      end
    end
  end

  describe "#toggle_carts_item" do
    let!(:carts_item) { create(:carts, user: user, book: book, quantity: 2, is_deleted: false) }

    it "removes an item from the carts when toggled" do
      result = carts_service.toggle_carts_item(book.id)
      expect(result[:success]).to be_truthy
      expect(result[:message]).to eq("Item removed from carts.")
      expect(carts_item.reload.is_deleted).to be_truthy
    end

    it "restores an item back to the carts when toggled again" do
      carts_service.toggle_carts_item(book.id) # First toggle -> removed
      result = carts_service.toggle_carts_item(book.id) # Second toggle -> restored

      expect(result[:success]).to be_truthy
      expect(result[:message]).to eq("Item restored from carts.")
      expect(carts_item.reload.is_deleted).to be_falsey
    end

    it "returns error if item is not in the carts" do
      result = carts_service.toggle_carts_item(9999) # Non-existent book ID
      expect(result[:success]).to be_falsey
      expect(result[:message]).to eq("Item not found in carts")
    end
  end

  describe "#view_carts" do
    let!(:carts_item) { create(:carts, user: user, book: book, quantity: 2) }

    it "returns carts details correctly" do
      result = carts_service.view_carts(1, 10)

      expect(result[:success]).to be_truthy
      expect(result[:carts].size).to eq(1)
      expect(result[:carts].first[:book_id]).to eq(book.id)
      expect(result[:carts].first[:total_price]).to eq(400) # 200 * 2
    end
  end

#   describe "#clear_carts" do
#     let!(:carts_item1) { create(:carts, user: user, book: book, quantity: 2) }
#     let!(:carts_item2) { create(:carts, user: user, book: create(:book, quantity: 1)) } #5 -> 1

#     it "clears all carts items" do
#       result = carts_service.clear_carts
#       expect(result[:success]).to be_truthy
#       expect(user.cartss.where(is_deleted: false).count).to eq(0)
#     end
#   end

  describe "#update_quantity" do
    let!(:carts_item) { create(:carts, user: user, book: book, quantity: 2) }

    it "updates quantity when within stock" do
      result = carts_service.update_quantity(book.id, 5)
      expect(result[:success]).to be_truthy
      expect(result[:message]).to eq("Quantity updated.")
      expect(carts_item.reload.quantity).to eq(5)
    end

    it "rejects update if new quantity is greater than stock" do
      result = carts_service.update_quantity(book.id, 15)
      expect(result[:success]).to be_falsey
      expect(result[:message]).to eq("Not enough stock available.")
    end

    it "returns error if item is not in carts" do
      result = carts_service.update_quantity(9999, 2)
      expect(result[:success]).to be_falsey
      expect(result[:message]).to eq("Item not found in carts")
    end
  end
end
