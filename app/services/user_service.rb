class UserService

  def self.signup(params)
    required_keys = [:full_name, :email, :password, :mobile_number]
    missing_keys = required_keys.select { |key| params[key].blank? }

    if missing_keys.any?
      return { success: false, error: "Missing required fields: #{missing_keys.join(', ')}" }
    end

    if User.exists?(email: params[:email].downcase)
      return { success: false, error: "Email already taken. Please use a different email." }
    end

    user = User.new(params)

    if params[:password_confirmation] && params[:password] != params[:password_confirmation]
      return { success: false, error: "Passwords do not match." }
    end
    
    if user.save
      Rails.logger.info "✅ User registered successfully: #{user.email}"
      { success: true, message: "User registered successfully", user: user }
    else
      Rails.logger.warn "⚠️ Sign-up failed: #{user.errors.full_messages.join(', ')}"
      { success: false, error: user.errors.full_messages.join(", ") }
    end
  end


  
  def self.login(email,password)
    user = User.find_by(email: email.downcase)
    if user&.authenticate(password)
      token =JwtService.encode({user_id:user.id})
      {success:true,user: user,token: token}
    else
      {success:false,error: "Invalid email or password"}
   end
 end
end