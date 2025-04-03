module Api
  module V1
    class GithubAuthController < ApplicationController
      skip_before_action :authenticate_request, only: :login

      def login
        unless params[:code].present?
          return render json: { error: "GitHub code is required" }, status: :bad_request
        end
      
        result = GithubAuthService.new(params[:code]).authenticate
        if result.success
          render json: {
            message: "Authentication successful",
            user: { email: result.user.email, full_name: result.user.full_name },
            access_token: result.access_token,
            refresh_token: result.refresh_token,
            expires_in: 15 * 60 # 15 minutes
          }, status: :ok
        else
          render json: { error: result.error }, status: result.status
        end
      end
    end
  end
end