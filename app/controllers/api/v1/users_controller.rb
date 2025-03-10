class Api::V1::UsersController < ApplicationController
  skip_before_action :authenticate_request, only: [:signup, :login, :forgot_password, :reset_password]

  def signup
    result = UserService.signup(user_params)

    if result[:success]
      render json: { message: 'User registered successfully', user: result[:user] }, status: :created
    else
      render json: { errors: result[:error] }, status: :unprocessable_entity
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
end
