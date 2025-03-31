require 'net/http'
require 'json'

class GoogleAuthService
  Result = Struct.new(:success, :user, :access_token, :refresh_token, :error, :status)

  GOOGLE_TOKENINFO_URI = ENV['GOOGLE_TOKENINFO_URI'] || 'https://oauth2.googleapis.com/tokeninfo'

  def initialize(token)
    @token = token
  end

  def authenticate
    Rails.logger.info "Received Google token: #{@token}"
    return Result.new(false, nil, nil, nil, "No token provided", :bad_request) if @token.blank?

    uri = URI("#{GOOGLE_TOKENINFO_URI}?id_token=#{URI.encode_www_form_component(@token)}")
    Rails.logger.info "Requesting Google API: #{uri}"

    begin
      response = Net::HTTP.get_response(uri)
      Rails.logger.info "Google API response: #{response.code} - #{response.body}"
      payload = JSON.parse(response.body)
      Rails.logger.info "Parsed payload: #{payload.inspect}"

      if response.is_a?(Net::HTTPSuccess)
        unless payload["sub"]
          return Result.new(false, nil, nil, nil, "Invalid Google token: No subject ID", :unauthorized)
        end

        user = find_or_create_user(payload)
        unless user.persisted?
          Rails.logger.error "Validation failed: #{user.errors.full_messages.inspect}"
          return Result.new(false, nil, nil, nil, "Validation failed: #{user.errors.full_messages.join(', ')}", :unprocessable_entity)
        end

        tokens = generate_tokens(user)
        decoded_access = JwtService.decode_access_token(tokens[:access_token])
        decoded_refresh = JwtService.decode_refresh_token(tokens[:refresh_token])
        if decoded_access.nil? || decoded_refresh.nil?
          Rails.logger.error "Token generation failed - Access: #{tokens[:access_token]}, Refresh: #{tokens[:refresh_token]}"
          return Result.new(false, nil, nil, nil, "Failed to generate valid tokens", :internal_server_error)
        end

        Result.new(true, user, tokens[:access_token], tokens[:refresh_token], nil, :ok)
      else
        return Result.new(false, nil, nil, nil, "Invalid Google token: #{payload['error'] || response.body}", :unauthorized)
      end
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing error: #{e.message}"
      return Result.new(false, nil, nil, nil, "Invalid Google response format", :bad_request)
    rescue StandardError => e
      Rails.logger.error "Unexpected error: #{e.message}"
      return Result.new(false, nil, nil, nil, "Unexpected error: #{e.message}", :internal_server_error)
    end
  end

  private

  def find_or_create_user(payload)
    user = User.find_by(google_id: payload["sub"]) || User.find_by(email: payload["email"])
    if user
      user.update(google_id: payload["sub"]) unless user.google_id
      Rails.logger.info "Updated existing user: #{user.id}"
    else
      user = User.new(
        google_id: payload["sub"],
        email: payload["email"],
        full_name: payload["name"] || "Unknown",
        mobile_number: payload["mobile_number"] || nil,
        password: "temp12345"
      )
      Rails.logger.info "New user attributes: #{user.attributes.inspect}"
      user.save!
      Rails.logger.info "New user created: #{user.id}"
    end
    user
  end

  def generate_tokens(user)
    access_token_payload = { user_id: user.id }
    refresh_token_payload = { user_id: user.id }
    access_exp = 15.minutes.from_now.to_i
    refresh_exp = 30.days.from_now.to_i

    access_token = JwtService.encode_access_token(access_token_payload, access_exp)
    refresh_token = JwtService.encode_refresh_token(refresh_token_payload, refresh_exp)

    Rails.logger.info "Access token expiration: #{Time.at(access_exp).utc}"
    Rails.logger.info "Refresh token expiration: #{Time.at(refresh_exp).utc}"

    { access_token: access_token, refresh_token: refresh_token }
  end
end