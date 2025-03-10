class UserMailer < ApplicationMailer
  default from: 'akshaykatoch38@gmail.com'

  def send_otp(user,otp,expiry_time)
    @user = user
    @otp = otp
    @expiry_time = expiry_time.strftime("%I:%M %p")
    mail(to: @user.email,subject:"Your OTP for password Reset")
  end
  
end
