class Api::V1::UsersController < ApplicationController
  skip_before_action :authenticate_request, only: [:signup, :login, :forgot_password, :reset_password]

  def profile
    unless @current_user
      return render json: { success: false, error: "User not authenticated" }, status: :unauthorized
    end

    if request.get?
      render json: { 
        success: true,
        name: @current_user.full_name || "Unknown",
        email: @current_user.email || "No email",
        mobile_number: @current_user.mobile_number
      }, status: :ok
    elsif request.patch? || request.put?
      # Extract password-related params
      current_password = profile_params[:current_password]
      new_password = profile_params[:new_password]

      # If password fields are provided, verify current_password and update new_password
      if current_password.present? || new_password.present?
        unless @current_user.authenticate(current_password)
          return render json: { success: false, errors: ["Current password is incorrect"] }, status: :unprocessable_entity
        end
        unless new_password.present?
          return render json: { success: false, errors: ["New password cannot be blank"] }, status: :unprocessable_entity
        end
        # Assign new password to user attributes
        @current_user.password = new_password
      end

      # Update other profile fields (excluding password fields from direct update)
      profile_attributes = profile_params.except(:current_password, :new_password)
      if @current_user.update(profile_attributes)
        render json: { 
          success: true,
          message: "Profile updated successfully",
          name: @current_user.full_name,
          email: @current_user.email,
          mobile_number: @current_user.mobile_number
        }, status: :ok
      else
        render json: { 
          success: false,
          errors: @current_user.errors.full_messages 
        }, status: :unprocessable_entity
      end
    end
  rescue StandardError => e
    Rails.logger.error "Profile update error: #{e.message}\n#{e.backtrace.join("\n")}"
    render json: { success: false, error: "Server error: #{e.message}" }, status: :internal_server_error
  end

  def signup
    result = UserService.signup(user_params)
    if result.success?
      render json: {
        message: 'User registered successfully',
        user: result.user.as_json(only: [:id, :email, :full_name])
      }, status: :created
    else
      render json: { errors: result.error }, status: :unprocessable_entity
    end
  end
  
  def login
    result = UserService.login(params[:email], params[:password])
    if result[:success]
      render json: { message: 'Login successful', user: result[:user], token: result[:token] }, status: :ok
    else
      render json: { errors: result[:error] }, status: :unauthorized
    end
  end

  def forgot_password
    result = PasswordService.forgot_password(params[:email])
    if result[:success]
      render json: { message: result[:message] }, status: :ok
    else
      render json: { errors: result[:error] }, status: :unprocessable_entity
    end
  end

  def reset_password
    result = PasswordService.reset_password(params[:email], params[:otp], params[:new_password])
    if result[:success]
      render json: { message: result[:message] }, status: :ok
    else
      render json: { errors: result[:error] }, status: :unprocessable_entity
    end
  end

  private 

  def user_params
    params.require(:user).permit(:full_name, :email, :password, :mobile_number)
  end

  def profile_params
    params.require(:user).permit(:full_name, :email, :mobile_number, :current_password, :new_password)
  end
end