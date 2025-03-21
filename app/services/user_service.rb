# app/services/user_service.rb
class UserService
  Result = Struct.new(:success, :user, :token, :error, keyword_init: true) do
    def success?
      success
    end
  end

  def self.signup(params)
    user = User.new(params)

    if user.save
      Rails.logger.info "User signup successful: #{user.id}"
      Result.new(success: true, user: user)
    else
      Result.new(success: false, error: user.errors.full_messages.join(', '))
    end
  rescue StandardError => e
    Rails.logger.error "Unexpected error during signup: #{e.message}"
    Result.new(success: false, error: "An unexpected error occurred: #{e.message}")
  end

  def self.login(email, password)
    user = User.find_by(email: email&.downcase)

    if user&.authenticate(password)
      token = JwtService.encode(user_id: user.id)
      Rails.logger.info "User login successful: #{user.id}"
      Result.new(success: true, user: user, token: token)
    else
      Result.new(success: false, error: 'Invalid email or password')
    end
  rescue StandardError => e
    Rails.logger.error "Unexpected error during login: #{e.message}"
    Result.new(success: false, error: "An unexpected error occurred: #{e.message}")
  end
end