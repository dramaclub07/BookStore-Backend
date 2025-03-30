# app/controllers/api/v1/google_auth_controller.rb
module Api
  module V1
    class GoogleAuthController < ApplicationController
      require 'net/http'
      require 'json'

      skip_before_action :authenticate_request, only: :create

      GOOGLE_TOKENINFO_URI = ENV['GOOGLE_TOKENINFO_URI'] || 'https://oauth2.googleapis.com/tokeninfo'

      def create
        token = params[:token]
        Rails.logger.info "Received Google token: #{token}"
        return render json: { error: "No token provided" }, status: :bad_request if token.blank?

        uri = URI("#{GOOGLE_TOKENINFO_URI}?id_token=#{URI.encode_www_form_component(token)}")
        Rails.logger.info "Requesting Google API: #{uri}"

        begin
          response = Net::HTTP.get_response(uri)
          Rails.logger.info "Google API response: #{response.code} - #{response.body}"

          payload = JSON.parse(response.body)
          Rails.logger.info "Parsed payload: #{payload.inspect}"

          if response.is_a?(Net::HTTPSuccess)
            unless payload["sub"]
              render json: { error: "Invalid Google token", details: "No subject ID in response" }, status: :unauthorized
              return
            end

            user = User.find_by(google_id: payload["sub"]) || User.find_by(email: payload["email"])

            if user
              user.update(google_id: payload["sub"]) unless user.google_id
              Rails.logger.info "Updated existing user: #{user.id}"
            else
              user = User.new(
                google_id: payload["sub"],
                email: payload["email"],
                full_name: payload["name"] || "Unknown",
                mobile_number: payload["mobile_number"] || nil
              )
              Rails.logger.info "New user attributes: #{user.attributes.inspect}"
              unless user.save
                Rails.logger.error "Validation failed: #{user.errors.full_messages}"
                render json: { error: "Validation failed: #{user.errors.full_messages.join(', ')}" }, 
                      status: :unprocessable_entity
                return
              end
              Rails.logger.info "New user created: #{user.id}"
            end

            # Generate tokens with explicit expiration logging
            access_token_payload = { user_id: user.id }
            refresh_token_payload = { user_id: user.id }

            access_exp = 15.minutes.from_now.to_i
            refresh_exp = 30.days.from_now.to_i

            access_token = JwtService.encode_access_token(access_token_payload, access_exp)
            refresh_token = JwtService.encode_refresh_token(refresh_token_payload, refresh_exp)

            # Verify tokens immediately after generation
            decoded_access = JwtService.decode_access_token(access_token)
            decoded_refresh = JwtService.decode_refresh_token(refresh_token)

            Rails.logger.info "Access token expiration: #{Time.at(access_exp).utc}"
            Rails.logger.info "Refresh token expiration: #{Time.at(refresh_exp).utc}"
            Rails.logger.info "Decoded access token: #{decoded_access.inspect}"
            Rails.logger.info "Decoded refresh token: #{decoded_refresh.inspect}"

            if decoded_access.nil? || decoded_refresh.nil?
              Rails.logger.error "Token generation failed - Access: #{access_token}, Refresh: #{refresh_token}"
              render json: { error: "Failed to generate valid tokens" }, status: :internal_server_error
              return
            end

            render json: {
              message: "Authentication successful",
              user: { email: user.email, full_name: user.full_name },
              access_token: access_token,
              refresh_token: refresh_token,
              expires_in: 15 * 60 # 15 minutes in seconds
            }, status: :ok
          else
            render json: { error: "Invalid Google token", details: payload["error"] || response.body }, status: :unauthorized
          end
  
        rescue JSON::ParserError => e
          Rails.logger.error "JSON parsing error: #{e.message}"
          render json: { error: "Invalid Google response format" }, status: :bad_request
        rescue StandardError => e
          Rails.logger.error "Unexpected error: #{e.message}"
          render json: { error: "Unexpected error: #{e.message}" }, status: :internal_server_error
        end
      end
    end
  end
end

