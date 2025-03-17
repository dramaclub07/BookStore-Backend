class Api::V1::UsersController < ApplicationController
  skip_before_action :authenticate_request, only: [:signup, :login, :forgot_password, :reset_password]
  before_action :ensure_json_request # Ensure Rails Parses JSON Correctly

  def signup
    result = UserService.signup(user_params)

    if result[:success]
      Rails.logger.info "✅ User signed up successfully: #{result[:user].email}"
      render json: { message: 'User registered successfully', user: result[:user] }, status: :created
    else
      Rails.logger.warn "⚠️ Signup failed: #{result[:error]}"
      render json: { errors: Array(result[:error]) }, status: :unprocessable_entity
    end
  end

  def login
    Rails.logger.debug "🔍 Raw Request Body: #{request.body.read}"
    Rails.logger.debug "🔹 Received Params: #{params.inspect}"

    email = login_params[:email]
    password = login_params[:password]

    Rails.logger.debug "📩 Extracted Email: #{email.inspect}"
    Rails.logger.debug "🔑 Extracted Password: #{password.inspect}"

    if email.blank? || password.blank?
      Rails.logger.warn "⚠️ Login failed: Missing email or password"
      render json: { error: "Email and password are required" }, status: :unprocessable_entity
      return
    end

    result = UserService.login(email, password)

    if result[:success]
      Rails.logger.info "✅ Login successful for user: #{email}"
      render json: { message: 'Login successful', user: result[:user], token: result[:token] }, status: :ok
    else
      Rails.logger.warn "🚫 Login failed for user: #{email} - Reason: #{result[:error]}"
      render json: { errors: result[:error] }, status: :unauthorized
    end
  end

  def forgot_password
    result = PasswordService.forgot_password(params[:email])

    if result[:success]
      Rails.logger.info "📩 Password reset email sent to: #{params[:email]}"
      render json: { message: result[:message] }, status: :ok
    else
      Rails.logger.warn "🚫 Forgot password request failed: #{result[:error]}"
      render json: { errors: result[:error] }, status: :unprocessable_entity
    end
  end

  def reset_password
    result = PasswordService.reset_password(params[:email], params[:otp], params[:new_password])

    if result[:success]
      Rails.logger.info "🔄 Password reset successful for: #{params[:email]}"
      render json: { message: result[:message] }, status: :ok
    else
      Rails.logger.warn "🚫 Password reset failed: #{result[:error]}"
      render json: { errors: result[:error] }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:full_name, :email, :password, :mobile_number)
  end

  def login_params
    params.require(:email)
    params.require(:password)
    params.permit(:email, :password)
end

  def ensure_json_request
    unless request.content_type == "application/json"
      Rails.logger.warn "🚫 Invalid request format: Expected application/json, got #{request.content_type}"
      render json: { error: "Content-Type must be application/json" }, status: :unsupported_media_type
    end
  end
end
