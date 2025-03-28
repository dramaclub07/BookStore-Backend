class UserMailer < ApplicationMailer
  default from: 'noreply@bookstore.com'

  def send_otp(user, otp, expiry_time)
    @user = user
    @otp = otp
    @expiry_time = expiry_time.strftime("%I:%M %p")
    mail(to: @user.email, subject: "Your OTP for Password Reset")
  end

  def welcome_email(user, timestamp = Time.now)
    @user = user
    @timestamp = timestamp.strftime("%I:%M %p")
    mail(to: @user.email, subject: "Welcome to Our Bookstore!")
  end

  def order_confirmation_email(user, order, timestamp = Time.now)
    @user = user
    @order = order
    @timestamp = timestamp.strftime("%I:%M %p")
    mail(to: @user.email, subject: "Order Confirmation ##{order.id}")
  end

  def reset_confirmation_email(user, timestamp = Time.now)
    @user = user
    @timestamp = timestamp.strftime("%I:%M %p")
    mail(to: @user.email, subject: "Password Reset Confirmation")
  end

  def cancel_order_email(user, order, timestamp = Time.now) # New method
    @user = user
    @order = order
    @timestamp = timestamp.strftime("%I:%M %p")
    mail(to: @user.email, subject: "Order Cancellation ##{order.id}")
  end
end
