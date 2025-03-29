module Api
  module V1
    class OrdersController < ApplicationController
      before_action :authenticate_request
      before_action :set_order, only: [:show, :cancel, :update]

      def user_orders
        result = OrdersService.fetch_user_orders(@current_user)
        render json: result, status: :ok
      end

      def create
        if params[:address_id].present? && params[:order].blank?
          result = OrdersService.create_order_from_cart(@current_user, params[:address_id])
        else
          result = OrdersService.create_order(@current_user, params[:order] || {})
        end

        if result[:success]
          render json: result, status: :created
        else
          render json: result, status: :unprocessable_entity
        end
      end

      def show
        result = OrdersService.fetch_order(@current_user, params[:id])
        if result[:success]
          render json: result, status: :ok
        else
          render json: result, status: :not_found
        end
      end

      def cancel
        return if performed?
        result = OrdersService.cancel_order(@current_user, params[:id])
        if result[:success]
          render json: result, status: :ok
        else
          render json: result, status: :unprocessable_entity
        end
      end

      def update
        return if performed?
        result = OrdersService.update_order_status(@current_user, params[:id], params[:status])
        if result[:success]
          render json: result, status: :ok
        else
          render json: result, status: :unprocessable_entity
        end
      end

      private

      def set_order
        @order = @current_user.orders.find_by(id: params[:id])
        return if @order
        render json: { success: false, message: "Order not found" }, status: :not_found
      end
    end
  end
end