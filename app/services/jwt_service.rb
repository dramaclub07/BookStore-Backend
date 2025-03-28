require 'jwt'

class JwtService
  SECRET_KEY = ENV.fetch('JWT_SECRET_KEY', 'fallback_secret_key')
  REFRESH_SECRET_KEY = ENV.fetch('JWT_REFRESH_SECRET_KEY', 'fallback_refresh_secret_key') # Separate key for refresh tokens

  # Encode an access token with a short expiration (e.g., 15 minutes)
  def self.encode_access_token(payload, exp = 15.minutes.from_now.to_i)
    payload[:exp] = exp
    JWT.encode(payload, SECRET_KEY, 'HS256')
  end

  # Encode a refresh token with a longer expiration (e.g., 30 days)
  def self.encode_refresh_token(payload, exp = 30.days.from_now.to_i)
    payload[:exp] = exp
    JWT.encode(payload, REFRESH_SECRET_KEY, 'HS256')
  end

  # Decode an access token
  def self.decode_access_token(token)
    decoded_token = JWT.decode(token, SECRET_KEY, true, algorithms: ['HS256'])[0]
    decoded_token.symbolize_keys
  rescue JWT::ExpiredSignature
    Rails.logger.warn "Access Token has expired"
    nil
  rescue JWT::DecodeError => e
    Rails.logger.warn "Access Token Decode Error: #{e.message}"
    nil
  end

  # Decode a refresh token
  def self.decode_refresh_token(token)
    decoded_token = JWT.decode(token, REFRESH_SECRET_KEY, true, algorithms: ['HS256'])[0]
    decoded_token.symbolize_keys
  rescue JWT::ExpiredSignature
    Rails.logger.warn "Refresh Token has expired"
    nil
  rescue JWT::DecodeError => e
    Rails.logger.warn "Refresh Token Decode Error: #{e.message}"
    nil
  end
end