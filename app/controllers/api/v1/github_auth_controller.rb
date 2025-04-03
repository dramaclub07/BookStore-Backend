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
          Rails.logger.error "GitHub authentication failed: #{result.error}"
          render json: { 
            error: result.error || 'Authentication failed'
          }, status: result.status || :unauthorized
        end
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "User validation failed: #{e.record.errors.full_messages.join(', ')}"
        render json: { error: 'User validation failed: ' + e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
      rescue StandardError => e
        Rails.logger.error "Unexpected GitHub OAuth error: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: 'Internal authentication error' }, status: :internal_server_error
      end
    end
  end
end
  