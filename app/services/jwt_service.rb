require 'jwt'

class JwtService
  SECRET_KEY = ENV['JWT_SECRET_KEY'] || 'fallback_secret_key'

  # Encode a JWT Token
  def self.encode(payload)
    JWT.encode(payload, SECRET_KEY, 'HS256')
  end

  # Decode a JWT Token
  def self.decode(token)
    decoded_token = JWT.decode(token, SECRET_KEY, true, algorithm: 'HS256')[0]
    decoded_token.symbolize_keys 
  rescue JWT::DecodeError
    nil
  end
end
