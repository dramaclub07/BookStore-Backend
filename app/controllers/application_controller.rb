class ApplicationController < ActionController::API
  before_action :authenticate_request

  attr_reader :current_user  

  private

  def authenticate_request
    token = request.headers['Authorization']&.split(' ')&.last

    if token.blank?
      Rails.logger.debug "Authentication failed: Missing token"
      render json: { success: false, message: 'Unauthorized - Missing token' }, status: :unauthorized
      return
    end

    decoded_token = JwtService.decode(token) rescue nil

    if decoded_token.nil?
      Rails.logger.debug "Authentication failed: Invalid token"
      render json: { success: false, message: 'Unauthorized - Invalid token' }, status: :unauthorized
      return
    end

    @current_user = User.find_by(id: decoded_token[:user_id])

    if @current_user.nil?
      Rails.logger.debug "Authentication failed: User not found"
      render json: { success: false, message: 'Unauthorized - User not found' }, status: :unauthorized
    end
  end
  

  # def current_user
  #   @current_user
  # end why tf do we need this here? its clustering the cli output
end
