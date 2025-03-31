class PasswordService
  OTP_STORAGE = {} # Temporary storage (Use Redis in production)
  OTP_EXPIRY_TIME = 5 * 60 # 5 minutes in seconds

  def self.forgot_password(email)
    user = User.find_by(email: email)
     return { success: false, error: "User not found", status: :not_found } unless user

    otp = generate_otp
    expiry_time = Time.now + OTP_EXPIRY_TIME

    OTP_STORAGE[email] = { otp: otp, otp_expiry: expiry_time }
    EmailProducer.publish_email("send_otp", {
      user_id: user.id,
      otp: otp,
      expiry_time: expiry_time.to_s
    })
    { success: true, message: "OTP sent to your email" }
  end

  def self.reset_password(email, otp, new_password)
    user = User.find_by(email: email)
    return { success: false, error: "User not found" } unless user

    stored_otp_data = OTP_STORAGE[email]
    return { success: false, error: "OTP not found" } unless stored_otp_data
    return { success: false, error: "OTP expired" } if Time.now > stored_otp_data[:otp_expiry]
    return { success: false, error: "Invalid OTP" } unless stored_otp_data[:otp] == otp

    if user.update(password: new_password)
      OTP_STORAGE.delete(email)
      EmailProducer.publish_email("reset_confirmation_email", { user_id: user.id })
      { success: true, message: "Password reset successfully" }
    else
      { success: false, error: user.errors.full_messages.join(", ") }
    end
  end

  private

  def self.generate_otp
    rand(100000..999999).to_s # Generate 6-digit OTP
  end
end