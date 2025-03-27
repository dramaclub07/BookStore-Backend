class UserMailer < ApplicationMailer
  default from: 'akshaykatoch38@gmail.com'

  def send_otp(user,otp,expiry_time)
    @user = user
    @otp = otp
    @expiry_time = expiry_time.strftime("%I:%M %p")
    mail(to: @user.email,subject:"Your OTP for password Reset")
  end
  
  def self.enqueue_welcome_email(user)
    channel = RabbitMQ.create_channel
    queue = channel.queue("welcome_emails") # New queue for welcome emails
    message = { email: user.email, user_name: user.name }.to_json
    queue.publish(message, persistent: true)
    channel.close
  end

  def welcome_email(user)
    @user = user
    mail(to: @user.email, subject: "Welcome to Book Store, #{@user.name}!")
  end
end
