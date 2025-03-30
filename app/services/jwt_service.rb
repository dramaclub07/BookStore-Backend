require 'jwt'

class JwtService
  SECRET_KEY = ENV.fetch('JWT_SECRET_KEY', 'fallback_secret_key')
  REFRESH_SECRET_KEY = ENV.fetch('JWT_REFRESH_SECRET_KEY', 'fallback_refresh_secret_key')

  def self.encode_access_token(payload, exp = 1.minutes.from_now.to_i)
    payload[:exp] = exp
    payload[:role] = User.find(payload[:user_id]).role # Add role to payload
    JWT.encode(payload, SECRET_KEY, 'HS256')
  end

  def self.encode_refresh_token(payload, exp = 2.minutes.from_now.to_i)
    payload[:exp] = exp
    payload[:role] = User.find(payload[:user_id]).role # Add role to payload
    JWT.encode(payload, REFRESH_SECRET_KEY, 'HS256')
  end

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