require 'rails_helper'

RSpec.describe CartService, type: :service do
  let(:user) { create(:user) }
  let(:book) { create(:book, quantity: 10, discounted_price: 200) }
  let(:cart_service) { described_class.new(user) }

  describe "#add_to_cart" do
    context "when adding a valid book with sufficient stock" do
      it "adds the book to the cart successfully" do
        result = cart_service.add_to_cart(book.id, 2)
        expect(result[:success]).to be_truthy
        expect(result[:message]).to eq("Item added to cart.")
        expect(user.carts.find_by(book: book).quantity).to eq(2)
      end
    end

    context "when book ID is invalid" do
      it "returns an error message" do
        result = cart_service.add_to_cart(9999, 2)
        expect(result[:success]).to be_falsey
        expect(result[:message]).to eq("Book not found or unavailable.")
      end
    end

    context "when quantity is invalid" do
      it "rejects zero or negative quantities" do
        result = cart_service.add_to_cart(book.id, 0)
        expect(result[:success]).to be_falsey
        expect(result[:message]).to eq("Invalid quantity.")
      end
    end

    context "when stock is insufficient" do
      it "prevents adding more than available stock" do
        result = cart_service.add_to_cart(book.id, 11)
        expect(result[:success]).to be_falsey
        expect(result[:message]).to eq("Not enough stock available.")
      end
    end
  end

  describe "#toggle_cart_item" do
    let!(:cart_item) { create(:cart, user: user, book: book, quantity: 2, is_deleted: false) }

    it "removes an item from the cart when toggled" do
      result = cart_service.toggle_cart_item(book.id)
      expect(result[:success]).to be_truthy
      expect(result[:message]).to eq("Item removed from cart.")
      expect(cart_item.reload.is_deleted).to be_truthy
    end

    it "restores an item back to the cart when toggled again" do
      cart_service.toggle_cart_item(book.id) # First toggle -> removed
      result = cart_service.toggle_cart_item(book.id) # Second toggle -> restored

      expect(result[:success]).to be_truthy
      expect(result[:message]).to eq("Item restored from cart.")
      expect(cart_item.reload.is_deleted).to be_falsey
    end

    it "returns error if item is not in the cart" do
      result = cart_service.toggle_cart_item(9999) # Non-existent book ID
      expect(result[:success]).to be_falsey
      expect(result[:message]).to eq("Item not found in cart")
    end
  end

  describe "#view_cart" do
    let!(:cart_item) { create(:cart, user: user, book: book, quantity: 2) }

    it "returns cart details correctly" do
      result = cart_service.view_cart(1, 10)

      expect(result[:success]).to be_truthy
      expect(result[:cart].size).to eq(1)
      expect(result[:cart].first[:book_id]).to eq(book.id)
      expect(result[:cart].first[:total_price]).to eq(400) # 200 * 2
    end
  end

  describe "#clear_cart" do
    let!(:cart_item1) { create(:cart, user: user, book: book, quantity: 2) }
    let!(:cart_item2) { create(:cart, user: user, book: create(:book, quantity: 10)) } # Ensure sufficient stock

    it "clears all cart items" do
      result = cart_service.clear_cart
      expect(result[:success]).to be_truthy
      expect(user.carts.where(is_deleted: false).count).to eq(0)
    end
  end

  describe "#update_quantity" do
    let!(:cart_item) { create(:cart, user: user, book: book, quantity: 2) }

    it "updates quantity when within stock" do
      result = cart_service.update_quantity(book.id, 5)
      expect(result[:success]).to be_truthy
      expect(result[:message]).to eq("Quantity updated successfully.")
      expect(cart_item.reload.quantity).to eq(5)
    end

    it "rejects update if new quantity is greater than stock" do
      result = cart_service.update_quantity(book.id, 15)
      expect(result[:success]).to be_falsey
      expect(result[:message]).to eq("Not enough stock available.")
    end

    it "returns error if item is not in cart" do
      result = cart_service.update_quantity(9999, 2)
      expect(result[:success]).to be_falsey
      expect(result[:message]).to eq("Item not found in cart")
    end
  end

  describe "#add_or_update_cart" do
    context "when adding a new item" do
      it "adds the item to the cart" do
        result = cart_service.add_or_update_cart(book.id, 3)
        expect(result[:success]).to be_truthy
        expect(result[:message]).to eq("Cart updated successfully.")
        expect(user.carts.find_by(book: book).quantity).to eq(3)
      end
    end

    context "when updating an existing item" do
      let!(:cart_item) { create(:cart, user: user, book: book, quantity: 2) }

      it "updates the quantity of the existing item" do
        result = cart_service.add_or_update_cart(book.id, 4)
        expect(result[:success]).to be_truthy
        expect(result[:message]).to eq("Cart updated successfully.")
        expect(cart_item.reload.quantity).to eq(4)
      end
    end
  end
end