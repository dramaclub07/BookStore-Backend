# app/controllers/api/v1/facebook_auth_controller.rb
module Api
  module V1
    class FacebookAuthController < ApplicationController
      require 'net/http'
      require 'json'

      # Skip JWT authentication for Facebook auth
      skip_before_action :authenticate_request, only: :create

      # Load from environment variables with defaults
      FACEBOOK_APP_ID = ENV['FACEBOOK_APP_ID'] || 'your_facebook_app_id'
      FACEBOOK_APP_SECRET = ENV['FACEBOOK_APP_SECRET'] || 'your_facebook_app_secret'
      FACEBOOK_TOKENINFO_URI = ENV['FACEBOOK_TOKENINFO_URI'] || 'https://graph.facebook.com/me'

      def create
        # Handle the access token from params
        token = params[:token] || params[:facebook_auth]&.[](:token)
        if token.blank?
          render json: { error: 'No token provided' }, status: :bad_request
          return
        end

        Rails.logger.info "Received Facebook access token (length: #{token.length})"

        # Verify the access token with Facebook
        uri = URI("#{FACEBOOK_TOKENINFO_URI}?access_token=#{URI.encode_www_form_component(token)}&fields=id,name,email")
        response = Net::HTTP.get_response(uri)
        Rails.logger.info "Facebook response: #{response.body}"

        if response.is_a?(Net::HTTPSuccess)
          payload = JSON.parse(response.body)
          unless payload['id']
            render json: { error: 'Invalid Facebook token', details: payload }, status: :unauthorized
            return
          end

          begin
            # Find or create the user
            user = User.find_by(facebook_id: payload['id']) || User.find_by(email: payload['email'])

            if user
              # If user exists with this email but no facebook_id, link the Facebook account
              user.update!(facebook_id: payload['id']) unless user.facebook_id
              Rails.logger.info "Linked Facebook account to existing user: #{user.id}"
            else
              # Create a new user
              user = User.new(
                facebook_id: payload['id'],
                email: payload['email'],
                full_name: payload['name'],
                skip_social_validations: true
              )
              Rails.logger.info "Creating new user with facebook_id: #{user.facebook_id}"
              Rails.logger.info "skip_social_validations? before save: #{user.skip_social_validations?}"
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
            Rails.logger.error "Error in FacebookAuthController: #{e.message}"
            render json: { error: 'An unexpected error occurred', details: e.message }, status: :internal_server_error
          end
        else
          render json: { error: 'Invalid token', details: response.body }, status: :unauthorized
        end
      rescue JSON::ParserError => e
        render json: { error: 'Failed to parse Facebook response', details: response.body }, status: :bad_request
      end
    end
  end
end