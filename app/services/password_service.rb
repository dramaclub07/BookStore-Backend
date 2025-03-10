class PasswordService

  
  OTP_STORAGE = {} # Temporary storage (Use Redis in production)
  OTP_EXPIRY_TIME = 5 * 60 # 5 minutes in seconds

  def self.forgot_password(email)
    user = User.find_by(email: email)
    return { success: false, error: "User not found" } unless user

    otp = generate_otp
    expiry_time = Time.now + OTP_EXPIRY_TIME # Set expiry time

    OTP_STORAGE[email] = { otp: otp, otp_expiry: expiry_time }

    UserMailer.send_otp(user, otp, expiry_time).deliver_now
    { success: true, message: "OTP sent to your email" }
  end




  def self.reset_password(email, otp, new_password)
    user = User.find_by(email: email)
    return { success: false, error: "User not found" } unless user

    stored_otp_data = OTP_STORAGE[email]
    return { success: false, error: "OTP not found" } unless stored_otp_data
    return { success: false, error: "OTP expired" } if Time.now > stored_otp_data[:otp_expiry]
    return { success: false, error: "Invalid OTP" } unless stored_otp_data[:otp] == otp

    user.update(password: new_password)
    OTP_STORAGE.delete(email) # Remove OTP after successful reset
    { success: true, message: "Password reset successfully" }
  end

  
  private

  def self.generate_otp
    rand(100000..999999).to_s # Generate 6-digit OTP
  end
end
