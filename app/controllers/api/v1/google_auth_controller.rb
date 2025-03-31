module Api
  module V1
    class GoogleAuthController < ApplicationController
      skip_before_action :authenticate_request, only: :create

      def create
        result = GoogleAuthService.new(params[:token]).authenticate

        if result.success
          render json: {
            message: "Authentication successful",
            user: { email: result.user.email, full_name: result.user.full_name },
            access_token: result.access_token,
            refresh_token: result.refresh_token,
            expires_in: 15 * 60
          }, status: :ok
        else
          render json: { error: result.error }, status: result.status
        end
      end
    end
  end
end