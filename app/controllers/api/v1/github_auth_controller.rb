module Api
  module V1
    class GithubAuthController < ApplicationController
      skip_before_action :authenticate_request, only: [:login, :callback]

      def login
        redirect_to "#{GithubAuthService::GITHUB_AUTH_URI}?client_id=#{ENV['GITHUB_CLIENT_ID']}&redirect_uri=#{github_callback_url}", allow_other_host: true
      end

      def callback
        result = GithubAuthService.new(params[:code]).authenticate
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

      private

      def github_callback_url
        'http://localhost:3000/api/v1/github_auth/callback'
      end
    end
  end
end