module Api
  module V1
    class AddressesController < ApplicationController
      before_action :authenticate_request
      before_action :set_address, only: [:show, :update, :destroy]


      def index
        result = AddressService.get_addresses(@current_user)
        render json: result, status: :ok
      end


      def create
        result = AddressService.create_address(@current_user, address_params)
        status = result[:success] ? :created : :unprocessable_entity
        render json: result, status: status
      end


      def show
        render json: { success: true, address: @address }, status: :ok
      end


      def update
        result = AddressService.update_address(@address, address_params)
        status = result[:success] ? :ok : :unprocessable_entity
        render json: result, status: status
      end


      def destroy
        result = AddressService.destroy_address(@address)
        render json: result, status: :ok
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
