module Api
  module V1
    class AddressesController < ApplicationController
      before_action :authenticate_request
      before_action :set_address, only: [:show, :update, :destroy]

      def index
        result = AddressService.get_addresses(@current_user)
        if result[:success]
          render json: { success: true, addresses: result[:addresses] }, status: :ok
        else
          render json: { success: false, error: result[:error] }, status: :unprocessable_entity
        end
      end 
def create
  begin
    result = AddressService.create_address(@current_user, address_params)
    status = result[:success] ? :created : :unprocessable_entity
    render json: result, status: status
  rescue StandardError => e
    Rails.logger.error("Error creating address: #{e.message}")
    render json: { success: false, errors: ["Failed to create address due to a server error"] }, status: :internal_server_error
  end
end

      def show
        if @address
          render json: { success: true, address: @address }, status: :ok
        else
          render json: { success: false, error: "Address not found" }, status: :not_found
        end
      end

      def update
        begin
          result = AddressService.update_address(@address, address_params)
          status = result[:success] ? :ok : :unprocessable_entity
          render json: result, status: status
        rescue ActiveRecord::RecordInvalid => e
          render json: { success: false, errors: e.record.errors.full_messages }, status: :unprocessable_entity
        end
      end

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
      rescue ActionController::ParameterMissing
        # Handle missing address key by returning an empty permitted hash
        ActionController::Parameters.new({})
      end
    end
  end
end