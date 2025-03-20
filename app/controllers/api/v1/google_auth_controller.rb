# app/controllers/api/v1/google_auth_controller.rb
module Api
  module V1
    class GoogleAuthController < ApplicationController
      require 'net/http'
      require 'json'

      # Skip JWT authentication for Google auth
      skip_before_action :authenticate_request, only: :create

      # Load from environment variables with defaults
      GOOGLE_CLIENT_ID = ENV['GOOGLE_CLIENT_ID'] || '487636959884-qpcsgvs3m6vcmjtmmt60mnpjb66bv2uj.apps.googleusercontent.com'
      GOOGLE_TOKENINFO_URI = ENV['GOOGLE_TOKENINFO_URI'] || 'https://oauth2.googleapis.com/tokeninfo'

      def create
        # Handle both "token" and "id_token" keys from params
        token = params[:token] || params[:google_auth]&.[](:token) || params[:id_token]
        if token.blank?
          render json: { error: 'No token provided' }, status: :bad_request
          return
        end

        Rails.logger.info "Received Google ID token (length: #{token.length})"

        # Construct URI using the tokeninfo endpoint from ENV
        uri = URI("#{GOOGLE_TOKENINFO_URI}?id_token=#{URI.encode_www_form_component(token)}")
        response = Net::HTTP.get_response(uri)
        Rails.logger.info "Google response: #{response.body}"

        if response.is_a?(Net::HTTPSuccess)
          payload = JSON.parse(response.body)
          unless payload['aud'] == GOOGLE_CLIENT_ID
            render json: { error: 'Token audience mismatch', expected: GOOGLE_CLIENT_ID, received: payload['aud'] }, status: :unauthorized
            return
          end

          begin
            # Find or create the user
            user = User.find_by(google_id: payload['sub']) || User.find_by(email: payload['email'])

            if user
              # If user exists with this email but no google_id, link the Google account
              user.update!(google_id: payload['sub']) unless user.google_id
              Rails.logger.info "Linked Google account to existing user: #{user.id}"
            else
              # Create a new user
              user = User.new(
                google_id: payload['sub'],
                email: payload['email'],
                full_name: payload['name'],
                skip_google_validations: true
              )
              Rails.logger.info "Creating new user with google_id: #{user.google_id}"
              Rails.logger.info "skip_google_validations? before save: #{user.skip_google_validations?}"
              Rails.logger.info "User attributes before save: #{user.attributes.inspect}"
              user.save!
              Rails.logger.info "New user created: #{user.id}"
            end

            # Generate a JWT token for your app
            jwt_token = JwtService.encode(user_id: user.id)
            render json: { message: 'Authentication successful', user: user.as_json, token: jwt_token }, status: :ok
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.error "Validation failed: #{e.message}"
            render json: { error: 'Failed to create or update user', details: e.message }, status: :unprocessable_entity
          rescue StandardError => e
            Rails.logger.error "Error in GoogleAuthController: #{e.message}"
            render json: { error: 'An unexpected error occurred', details: e.message }, status: :internal_server_error
          end
        else
          render json: { error: 'Invalid token', details: response.body }, status: :unauthorized
        end
      rescue JSON::ParserError => e
        render json: { error: 'Failed to parse Google response', details: response.body }, status: :bad_request
      end
    end
  end
end