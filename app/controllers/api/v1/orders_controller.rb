module Api
  module V1
    class OrdersController < ApplicationController
      before_action :authenticate_request
      before_action :set_order, only: [:show, :cancel, :update_status]

      
      def user_orders
        orders = @current_user.orders
        render json: { success: true, orders: orders }, status: :ok
      end

      
      def create
        order = @current_user.orders.new(order_params)
        if order.save
          render json: { success: true, order: order }, status: :created
        else
          render json: { success: false, errors: order.errors.full_messages }, status: :unprocessable_entity
        end
      end

      
      def show
        render json: { success: true, order: @order }, status: :ok
      end

      
      def cancel
        if @order.status != "cancelled"
          @order.update(status: "cancelled")
          render json: { success: true, message: "Order cancelled successfully", order: @order }, status: :ok
        else
          render json: { success: false, error: "Order is already cancelled" }, status: :unprocessable_entity
        end
      end

      
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

      def order_params
        params.require(:order).permit(:book_id, :quantity, :price_at_purchase, :total_price, :status, :address_id)
      end
    end
  end
end
