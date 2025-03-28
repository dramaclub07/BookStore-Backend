module Api
  module V1
    class OrdersController < ApplicationController
      before_action :authenticate_request
      before_action :set_order, only: [ :show, :cancel, :update ]

      # Get all orders of the logged-in user
      def user_orders
        orders = @current_user.orders
        render json: { success: true, orders: orders }, status: :ok
      end

      # Create an order from the books in the carts
      def create
        carts_items = @current_user.carts.active.includes(:book)

        if carts_items.empty?
          return render json: { success: false, message: "Your carts is empty. Add items before placing an order." }, status: :unprocessable_entity
        end

        orders = []
        carts_items.each do |carts_item|
          order = @current_user.orders.new(
            book_id: carts_item.book_id,
            quantity: carts_item.quantity,
            price_at_purchase: carts_item.book.discounted_price || carts_item.book.book_mrp,
            total_price: (carts_item.book.discounted_price || carts_item.book.book_mrp) * carts_item.quantity,
            status: "pending",
            address_id: params[:address_id]
          )

          if order.save
            orders << order
          else
            return render json: { success: false, errors: order.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # Clear the carts after successfully placing the orders
        carts_items.destroy_all

        render json: { success: true, message: "Order placed successfully", orders: orders }, status: :created
      end
      # Create an order
      # def create
      #   # If cart_items are provided, use them; otherwise, use direct params
      #   if params[:cart_items].present?
      #     create_from_cart
      #   else
      #     create_from_params
      #   end
      # end

      # Show order details
      def show
        render json: { success: true, order: @order }, status: :ok
      end

      # Cancel an order
      def cancel
        if @order.status != "cancelled"
          @order.update(status: "cancelled")
          EmailProducer.publish_email("cancel_order_email", { user_id: @current_user.id, order_id: @order.id })
          render json: { success: true, message: "Order cancelled successfully", order: @order }, status: :ok
        else
          render json: { success: false, error: "Order is already cancelled" }, status: :unprocessable_entity
        end
      end

      # Update order status
      def update
        valid_statuses = %w[pending processing shipped delivered cancelled]
        if valid_statuses.include?(params[:status])
          @order.update(status: params[:status])
          render json: { success: true, message: "Order status updated", order: @order }, status: :ok
        else
          render json: { success: false, error: "Invalid status" }, status: :unprocessable_entity
        end
      end

      private

      def set_order
        @order = @current_user.orders.find_by(id: params[:id])
        unless @order
          render json: { success: false, error: "Order not found" }, status: :not_found
        end
      end

      def create_from_cart
        # Validate address_id presence
        unless params[:address_id].present?
          return render json: { success: false, errors: [ "Address must be provided" ] }, status: :unprocessable_entity
        end

        address = Address.find_by(id: params[:address_id])
        unless address
          return render json: { success: false, errors: [ "Address not found" ] }, status: :unprocessable_entity
        end

        cart_items = @current_user.carts.active.includes(:book)
        if cart_items.empty?
          return render json: { success: false, errors: [ "Your cart is empty. Add items before placing an order." ] }, status: :unprocessable_entity
        end

        orders = []
        cart_items.each do |cart_item|
          order = build_order_from_cart_item(cart_item)
          if order.save
            orders << order
          else
            return render json: { success: false, errors: order.errors.full_messages }, status: :unprocessable_entity
          end
        end

        cart_items.destroy_all
        render json: { success: true, message: "Order placed successfully", orders: orders }, status: :created
      end

      def create_from_params
        # Validate address_id first
        unless params[:order][:address_id].present?
          return render json: { success: false, errors: [ "Address must be provided" ] }, status: :unprocessable_entity
        end

        address = Address.find_by(id: params[:order][:address_id])
        unless address
          return render json: { success: false, errors: [ "Address not found" ] }, status: :unprocessable_entity
        end

        # Validate book_id next
        unless params[:order][:book_id].present?
          return render json: { success: false, errors: [ "Book must be provided" ] }, status: :unprocessable_entity
        end

        book = Book.find_by(id: params[:order][:book_id])
        unless book
          return render json: { success: false, errors: [ "Book not found" ] }, status: :unprocessable_entity
        end

        # Create the order
        order = @current_user.orders.new(
          book_id: book.id,
          quantity: params[:order][:quantity] || 1,
          price_at_purchase: book.discounted_price || book.book_mrp || 10.99,
          total_price: (book.discounted_price || book.book_mrp || 10.99) * (params[:order][:quantity] || 1).to_i,
          status: "pending",
          address_id: address.id
        )

        if order.save
          EmailProducer.publish_email("order_confirmation_email", { user_id: @current_user.id, order_id: order.id })
          render json: { success: true, order: order.as_json }, status: :created
        else
          render json: { success: false, errors: order.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def build_order_from_cart_item(cart_item)
        @current_user.orders.new(
          book_id: cart_item.book_id,
          quantity: cart_item.quantity,
          price_at_purchase: cart_item.book.discounted_price || cart_item.book.book_mrp,
          total_price: (cart_item.book.discounted_price || cart_item.book.book_mrp) * cart_item.quantity,
          status: "pending",
          address_id: params[:address_id]
        )
      end
    end
  end
end
