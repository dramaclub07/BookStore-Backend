module Api
  module V1
    class GithubAuthController < ApplicationController
      skip_before_action :authenticate_request, only: [:login, :callback]

      def login
        state_token = SecureRandom.hex(32)
        OauthState.create!(state: state_token, expires_at: 10.minutes.from_now)
        Rails.logger.info "Setting GitHub OAuth state token: #{state_token}"

        auth_url = "#{GithubAuthService::GITHUB_AUTH_URI}?" + {
          client_id: ENV['GITHUB_CLIENT_ID'],
          redirect_uri: github_callback_url,
          scope: 'user:email',
          state: state_token,
          allow_signup: 'false'
        }.to_query

        redirect_to auth_url, allow_other_host: true
      end

      def callback
        unless params[:state].present?
          Rails.logger.error "Missing state parameter in callback"
          return render json: { error: 'Missing state parameter' }, status: :unprocessable_entity
        end

        oauth_state = OauthState.find_by(state: params[:state])
        if oauth_state.nil?
          Rails.logger.error "No OAuth state found in database"
          return render json: { error: 'Invalid state parameter' }, status: :unprocessable_entity
        end

        if oauth_state.expires_at < Time.current
          Rails.logger.error "OAuth state expired"
          oauth_state.destroy
          return render json: { error: 'State parameter expired' }, status: :unprocessable_entity
        end

        oauth_state.destroy
        Rails.logger.info "OAuth state verified and removed from database"

        result = GithubAuthService.new(params[:code]).authenticate
        if result.success
          Rails.logger.info "GitHub authentication successful for user: #{result.user.email}"
          render json: auth_success_response(result), status: :ok
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

      private

      def github_callback_url
        ENV.fetch('GITHUB_CALLBACK_URL', 'http://localhost:3000/api/v1/github_auth/callback')
      end

      def auth_success_response(result)
        {
          message: "Authentication successful",
          data: {
            user: {
              id: result.user.id,
              email: result.user.email,
              name: result.user.full_name
            },
            tokens: {
              access_token: result.access_token,
              refresh_token: result.refresh_token,
              expires_in: 15.minutes.to_i
            }
          }
        }
      end
    end
  end
end
