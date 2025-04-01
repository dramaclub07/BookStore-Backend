class Api::V1::UsersController < ApplicationController
  skip_before_action :authenticate_request, only: [:create, :login, :forgot_password, :reset_password]

  
  def profile
    unless @current_user
      return render json: { success: false, error: "User not authenticated" }, status: :unauthorized
    end
  
    if request.put?
      profile_attributes = profile_params.except(:current_password, :new_password).compact_blank
      Rails.logger.debug "Current user before update: #{@current_user.attributes.inspect}"
      Rails.logger.debug "Profile attributes to update: #{profile_attributes.inspect}"
      if @current_user.update(profile_attributes)
        Rails.logger.debug "User updated successfully: #{@current_user.attributes.inspect}"
        render json: { 
          success: true,
          message: "Profile updated successfully",
          name: @current_user.full_name,
          email: @current_user.email,
          mobile_number: @current_user.mobile_number,
          role: @current_user.role
        }, status: :ok
      else
        Rails.logger.debug "Update failed with errors: #{@current_user.errors.full_messages.inspect}"
        render json: { 
          success: false,
          errors: @current_user.errors.full_messages 
        }, status: :unprocessable_entity
      end
    else
      render json: { 
        success: true,
        name: @current_user.full_name,
        email: @current_user.email,
        mobile_number: @current_user.mobile_number,
        role: @current_user.role
      }, status: :ok
    end
  rescue StandardError => e
    Rails.logger.error "Profile update error: #{e.message}\n#{e.backtrace.join("\n")}"
    render json: { success: false, error: "Server error: #{e.message}" }, status: :internal_server_error
  end


def update_profile
  # Only permit the fields we want to allow for update
  update_params = params.require(:user).permit(:full_name, :email, :mobile_number)
  
  # Filter out blank values to prevent overwriting with empty strings
  update_params = update_params.reject { |_, v| v.blank? }

  if @current_user.update(update_params)
    render json: { 
      success: true,
      message: "Profile updated successfully",
      name: @current_user.full_name,
      email: @current_user.email,
      mobile_number: @current_user.mobile_number,
      role: @current_user.role
    }, status: :ok
  else
    render json: { 
      success: false,
      errors: @current_user.errors.full_messages 
    }, status: :unprocessable_entity
  end
end

  def create
    result = UserService.create(user_params)
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
    if result.success?
      render json: { 
        message: 'Login successful', 
        user: result.user.as_json(only: [:id, :email, :full_name, :role]), 
        access_token: result.access_token,
        refresh_token: result.refresh_token
      }, status: :ok
    else
      render json: { errors: result.error }, status: :unauthorized
    end
  end

  def forgot_password
    result = PasswordService.forgot_password(params[:email])
    if result[:success]
      render json: { success: true, message: result[:message] }, status: result[:status] || :ok
    else
      render json: { success: false, error: result[:error] }, status: result[:status] || :unprocessable_entity
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
    params.require(:user).permit(:full_name, :email, :password, :mobile_number, :role)
  end

  def profile_params
    params.require(:user).permit(:full_name, :email, :mobile_number, :current_password, :new_password)
  end
end