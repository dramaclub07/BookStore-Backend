class Api::V1::UsersController < ApplicationController
  skip_before_action :authenticate_request, only: [:signup, :login, :forgot_password, :reset_password]


  def profile
    unless @current_user
      return render json: { success: false, error: "User not authenticated" }, status: :unauthorized
    end

    # If it's a GET request, just return the profile
    if request.get?
      render json: { 
        success: true,
        name: @current_user.full_name || "Unknown",
        email: @current_user.email || "No email",
        mobile_number: @current_user.mobile_number
      }, status: :ok
    # If it's a PATCH/PUT request, update the profile
    elsif request.patch? || request.put?
      if @current_user.update(profile_params)
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

  def profile
    result = UserService.get_profile(current_user)

    if result[:success]
      render json: result.except(:success), status: :ok  # Remove :success key from response
    else
      render json: { errors: result[:error] }, status: :unprocessable_entity
    end
  end

  def update_profile
    result = UserService.update_profile(current_user, user_params)

    if result[:success]
      render json: { message: 'Profile updated successfully', user: result[:user] }, status: :ok
    else
      render json: { errors: result[:error] }, status: :unprocessable_entity
    end
  end

  private 

  def user_params
    params.require(:user).permit(:full_name, :email, :password, :mobile_number)
  end
  def profile_params
    params.require(:user).permit(:full_name, :email, :mobile_number)
  end
end
