module Api
  module V1
    class AddressesController < ApplicationController
      before_action :authenticate_request
      before_action :set_address, only: [:show, :update, :destroy]

      # GET /api/v1/addresses
      def index
        result = AddressService.get_addresses(@current_user)
        if result[:success]
          render json: { success: true, addresses: result[:addresses] }, status: :ok
        else
          render json: { success: false, error: result[:error] }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/addresses
      def create
        result = AddressService.create_address(@current_user, address_params)
        status = result[:success] ? :created : :unprocessable_entity
        render json: result, status: status
      end

      # GET /api/v1/addresses/:id
      def show
        if @address
          render json: { success: true, address: @address }, status: :ok
        else
          render json: { success: false, error: "Address not found" }, status: :not_found
        end
      end

      # PUT /api/v1/addresses/:id
      def update
        result = AddressService.update_address(@address, address_params)
        status = result[:success] ? :ok : :unprocessable_entity
        render json: result, status: status
      end

      # DELETE /api/v1/addresses/:id
      def destroy
        result = AddressService.destroy_address(@address)
        render json: result, status: :ok
      end

      private

      # Set the address instance based on the provided ID
      def set_address
        @address = @current_user.addresses.find_by(id: params[:id])
        unless @address
          render json: { success: false, error: "Address not found" }, status: :not_found
          return
        end
      end

      # Permitted parameters for address creation/update
      def address_params
        params.require(:address).permit(:street, :city, :state, :zip_code, :country, :address_type, :is_default)
      end
    end
  end
end