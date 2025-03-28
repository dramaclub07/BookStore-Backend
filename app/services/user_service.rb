class UserService
  # ✅ Define the Result constant at the class level
  Result = Struct.new(:success, :user, :access_token, :refresh_token, :error, keyword_init: true) do
    def success?
      success
    end
  end

  def self.create(params)
    user = User.new(params)
    if user.save
      Rails.logger.info "User signup successful: #{user.id}"
      EmailProducer.publish_email("welcome_email", { user_id: user.id })
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
      access_token = JwtService.encode_access_token(user_id: user.id)
      refresh_token = JwtService.encode_refresh_token(user_id: user.id)
      begin
        UserMailer.enqueue_welcome_email(user)
      rescue StandardError => e
        Rails.logger.error "Failed to enqueue welcome email: #{e.message}"
      end
      Rails.logger.info "User login successful: #{user.id}"
      Result.new(success: true, user: user, access_token: access_token, refresh_token: refresh_token)
    else
      Result.new(success: false, error: 'Invalid email or password')
    end
  rescue StandardError => e
    Rails.logger.error "Unexpected error during login: #{e.message}"
    Result.new(success: false, error: "An unexpected error occurred: #{e.message}")
  end

  # New method to refresh tokens
  def self.refresh_token(refresh_token)
    decoded = JwtService.decode_refresh_token(refresh_token)
    if decoded && decoded[:user_id]
      user = User.find_by(id: decoded[:user_id])
      if user
        new_access_token = JwtService.encode_access_token(user_id: user.id)
        Rails.logger.info "Token refreshed successfully for user: #{user.id}"
        Result.new(success: true, user: user, access_token: new_access_token, refresh_token: refresh_token)
      else
        Result.new(success: false, error: 'User not found')
      end
    else
      Result.new(success: false, error: 'Invalid or expired refresh token')
    end
  rescue StandardError => e
    Rails.logger.error "Unexpected error during token refresh: #{e.message}"
    Result.new(success: false, error: "An unexpected error occurred: #{e.message}")
  end

  def self.get_profile(user)
    {
      success: true,
      full_name: user.full_name,
      email: user.email,
      mobile_number: user.mobile_number
    }
  end

  def self.update_profile(user, params)
    if user.update(params.slice(:full_name, :email, :mobile_number))
      { success: true, message: "Profile updated successfully", user: user }
    else
      { success: false, error: user.errors.full_messages.join(", ") }
    end
  end
end