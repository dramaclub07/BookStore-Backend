module Api
  module V1
    class OrdersController < ApplicationController
      before_action :authenticate_request
      before_action :set_order, only: [:show, :cancel, :update_status]

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

      # Show order details
      def show
        render json: { success: true, order: @order }, status: :ok
      end

      # Cancel an order
      def cancel
        if @order.status != "cancelled"
          @order.update(status: "cancelled")
          render json: { success: true, message: "Order cancelled successfully", order: @order }, status: :ok
        else
          render json: { success: false, error: "Order is already cancelled" }, status: :unprocessable_entity
        end
      end

      # Update order status
      def update_status
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
    end
  end
end
