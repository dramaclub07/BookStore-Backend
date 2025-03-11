require 'jwt'

class JwtService
  SECRET_KEY = ENV.fetch('JWT_SECRET_KEY', 'fallback_secret_key')

  # Encode a JWT Token with expiration
  def self.encode(payload, exp = 24.hours.from_now.to_i)
    payload[:exp] = exp
    JWT.encode(payload, SECRET_KEY, 'HS256')
  end

  # Decode a JWT Token
  def self.decode(token)
    decoded_token = JWT.decode(token, SECRET_KEY, true, algorithms: ['HS256'])[0]
    decoded_token.symbolize_keys
  rescue JWT::ExpiredSignature
    Rails.logger.warn "JWT Token has expired"
    nil
  rescue JWT::DecodeError => e
    Rails.logger.warn "JWT Decode Error: #{e.message}"
    nil
  end
end
