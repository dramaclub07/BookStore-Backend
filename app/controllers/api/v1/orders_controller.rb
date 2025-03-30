module Api
  module V1
    class OrdersController < ApplicationController
      before_action :authenticate_request
      before_action :set_order, only: [:show, :update, :destroy]

      # GET /api/v1/orders
      def index
        result = OrdersService.fetch_all_orders(@current_user)
        render json: result, status: :ok
      end

      # POST /api/v1/orders
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

      # GET /api/v1/orders/:id
      def show
        result = OrdersService.fetch_order(@current_user, params[:id])
        render json: result, status: result[:success] ? :ok : :not_found
      end

      # PATCH /api/v1/orders/:id
      def update
        return if performed?
        result = OrdersService.update_order_status(@current_user, params[:id], params[:status])
        render json: result, status: result[:success] ? :ok : :unprocessable_entity
      end

      # DELETE /api/v1/orders/:id
      def destroy
        return if performed?
        result = OrdersService.cancel_order(@current_user, params[:id])
        render json: result, status: result[:success] ? :ok : :unprocessable_entity
      end

      private

      def set_order
        @order = @current_user.orders.find_by(id: params[:id])
        return if @order
        render json: { success: false, errors: ["Order not found"] }, status: :not_found
      end
    end
  end
end