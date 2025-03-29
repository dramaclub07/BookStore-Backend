class Api::V1::UsersController < ApplicationController
  skip_before_action :authenticate_request, only: [:create, :login, :forgot_password, :reset_password]

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
    elsif request.patch?
      current_password = profile_params[:current_password]
      new_password = profile_params[:new_password]

      if current_password.present? || new_password.present?
        unless @current_user.authenticate(current_password)
          return render json: { success: false, errors: ["Current password is incorrect"] }, status: :unprocessable_entity
        end
        unless new_password.present?
          return render json: { success: false, errors: ["New password cannot be blank"] }, status: :unprocessable_entity
        end
        @current_user.password = new_password
      end

      profile_attributes = @current_user.attributes.symbolize_keys.merge(profile_params.except(:current_password, :new_password).compact)
      Rails.logger.debug "Profile attributes: #{profile_attributes.inspect}"
      if @current_user.update(profile_attributes)
        render json: { 
          success: true,
          message: "Profile updated successfully",
          name: @current_user.full_name,
          email: @current_user.email,
          mobile_number: @current_user.mobile_number
        }, status: :ok
      else
        Rails.logger.debug "Update errors: #{@current_user.errors.full_messages}"
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

  def update_profile
    # Since there's a separate PUT route for 'user/profile'
    profile # Call the profile method since the logic is the same
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
        user: result.user.as_json(only: [:id, :email, :full_name]), 
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