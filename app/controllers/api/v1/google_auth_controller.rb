# app/controllers/api/v1/google_auth_controller.rb
require 'google-id-token'

module Api
  module V1
    class GoogleAuthController < ApplicationController
      skip_before_action :authenticate_request, only: :create

      GOOGLE_CLIENT_ID = ENV.fetch('GOOGLE_CLIENT_ID') { raise 'GOOGLE_CLIENT_ID must be set' }

      def create
        token = extract_token
        return render_error('No token provided', :bad_request) if token.blank?

        Rails.logger.info "Received Google ID token (length: #{token.length})"
        user = authenticate_with_google(token)
        return unless user

        jwt_token = JwtService.encode(user_id: user.id)
        render json: {
          message: 'Authentication successful',
          user: user.as_json(only: [:id, :email, :full_name]),
          token: jwt_token
        }, status: :ok
      rescue StandardError => e
        Rails.logger.error "Unexpected error: #{e.message}"
        render_error('An unexpected error occurred', :internal_server_error, details: e.message)
      end

      private

      def extract_token
        params[:token] || params.dig(:google_auth, :token) || params[:id_token]
      end

      def authenticate_with_google(token)
        validator = GoogleIDToken::Validator.new
        payload = validator.check(token, GOOGLE_CLIENT_ID)
        Rails.logger.info "Google token payload: #{payload.inspect}"

        find_or_create_user(payload)
      rescue GoogleIDToken::ValidationError => e
        Rails.logger.error "Google token validation failed: #{e.message}"
        render_error('Invalid token', :unauthorized, details: e.message)
        nil
      end

      def find_or_create_user(payload)
        user = User.find_by(google_id: payload['sub']) || User.find_by(email: payload['email'])

        if user
          user.update!(google_id: payload['sub']) unless user.google_id
          Rails.logger.info "Linked Google account to existing user: #{user.id}"
        else
          user = User.new(
            google_id: payload['sub'],
            email: payload['email'],
            full_name: payload['name']
          )
          Rails.logger.info "Creating user with attributes: #{user.attributes.inspect}"
          user.save!
          Rails.logger.info "New user created: #{user.id}"
        end
        user
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "User validation failed: #{e.message}"
        render_error('Failed to create or update user', :unprocessable_entity, details: e.message)
        nil
      end

      def render_error(message, status, details: nil)
        error_response = { error: message }
        error_response[:details] = details if details
        render json: error_response, status: status
      end
    end
  end
end