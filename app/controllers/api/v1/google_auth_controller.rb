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
        return render json: { error: 'No token provided' }, status: :bad_request if token.blank?

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
                mobile_number: payload["mobile_number"] || "9876543210"
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

            jwt_token = JwtService.encode({ user_id: user.id })
            Rails.logger.info "JWT token generated: #{jwt_token[0..10]}..."
            render json: { token: jwt_token }, status: :ok
          else
            render json: { error: "Invalid Google token", details: payload["error"] || response.body }, status: :unauthorized
          end
        rescue JSON::ParserError => e
          Rails.logger.error "JSON parsing error: #{e.message}"
          render json: { error: "Invalid Google response format" }, status: :bad_request
        rescue StandardError => e
          Rails.logger.error "Unexpected error: #{e.message}"
          render json: { error: e.message }, status: :internal_server_error
        end
      end
    end
  end
end