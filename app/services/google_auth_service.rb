require 'net/http'
require 'json'

class GoogleAuthService
  Result = Struct.new(:success, :user, :access_token, :refresh_token, :error, :status)

  GOOGLE_TOKENINFO_URI = ENV['GOOGLE_TOKENINFO_URI'] || 'https://oauth2.googleapis.com/tokeninfo'

  def initialize(token)
    @token = token
  end

  def authenticate
    return Result.new(false, nil, nil, nil, "No token provided", :bad_request) if @token.blank?

    uri = URI("#{GOOGLE_TOKENINFO_URI}?id_token=#{URI.encode_www_form_component(@token)}")

    begin
      response = Net::HTTP.get_response(uri)
      payload = JSON.parse(response.body)

      if response.is_a?(Net::HTTPSuccess)
        unless payload["sub"]
          return Result.new(false, nil, nil, nil, "Invalid Google token: No subject ID", :unauthorized)
        end

        user = find_or_create_user(payload)
        unless user.persisted?
          return Result.new(false, nil, nil, nil, "Validation failed: #{user.errors.full_messages.join(', ')}", :unprocessable_entity)
        end

        tokens = generate_tokens(user)
        decoded_access = JwtService.decode_access_token(tokens[:access_token])
        decoded_refresh = JwtService.decode_refresh_token(tokens[:refresh_token])
        if decoded_access.nil? || decoded_refresh.nil?
          return Result.new(false, nil, nil, nil, "Failed to generate valid tokens", :internal_server_error)
        end

        Result.new(true, user, tokens[:access_token], tokens[:refresh_token], nil, :ok)
      else
        return Result.new(false, nil, nil, nil, "Invalid Google token: #{payload['error'] || response.body}", :unauthorized)
      end
    rescue JSON::ParserError => e
      return Result.new(false, nil, nil, nil, "Invalid Google response format", :bad_request)
    rescue StandardError => e
      return Result.new(false, nil, nil, nil, "Unexpected error: #{e.message}", :internal_server_error)
    end
  end

  private

  def find_or_create_user(payload)
    user = User.find_by(google_id: payload["sub"]) || User.find_by(email: payload["email"])
    if user
      user.update(google_id: payload["sub"]) unless user.google_id
    else
      user = User.new(
        google_id: payload["sub"],
        email: payload["email"],
        full_name: payload["name"] || "Unknown",
        mobile_number: payload["mobile_number"] || nil,
        password: "temp12345"
      )
      user.save!
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


    { access_token: access_token, refresh_token: refresh_token }
  end
end