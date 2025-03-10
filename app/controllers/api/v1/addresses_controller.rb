module Api
  module V1
    class AddressesController < ApplicationController
      before_action :authenticate_request
      before_action :set_address, only: [:show, :update, :destroy]

      def index
        addresses = @current_user.addresses
        render json: { success: true, addresses: addresses }, status: :ok
      end

      def create
        address = @current_user.addresses.new(address_params)

        if address.save
          render json: { success: true, address: address }, status: :created
        else
          render json: { success: false, errors: address.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def show
        render json: { success: true, address: @address }, status: :ok
      end

      def update
        if @address.update(address_params)
          render json: { success: true, address: @address }, status: :ok
        else
          render json: { success: false, errors: @address.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @address.destroy
        render json: { success: true, message: "Address deleted successfully" }, status: :ok
      end

      private

      def set_address
        @address = @current_user.addresses.find_by(id: params[:id])
        unless @address
          render json: { success: false, error: "Address not found" }, status: :not_found
          return
        end
      end

      def address_params
        params.require(:address).permit(:street, :city, :state, :zip_code, :country, :address_type, :is_default)
      end
    end
  end
end