class ApplicationController < ActionController::API
  before_action :authenticate_request

  attr_reader :current_user, :current_role

  private

  def authenticate_request
    token = request.headers['Authorization']&.split(' ')&.last

    if token.blank?
      Rails.logger.debug "Authentication failed: Missing token"
      render json: { success: false, message: 'Unauthorized - Missing token' }, status: :unauthorized
      return
    end

    decoded_token = JwtService.decode_access_token(token)

    if decoded_token.nil?
      Rails.logger.debug "Authentication failed: Invalid or expired token"
      render json: { success: false, message: 'Unauthorized - Invalid or expired token' }, status: :unauthorized
      return
    end

    @current_user = User.find_by(id: decoded_token[:user_id])
    @current_role = decoded_token[:role] # Store the role from the token

    if @current_user.nil?
      Rails.logger.debug "Authentication failed: User not found"
      render json: { success: false, message: 'Unauthorized - User not found' }, status: :unauthorized
      return
    end

    Rails.logger.debug "Authentication successful for user: #{@current_user.id}, role: #{@current_role}"
  rescue StandardError => e
    Rails.logger.error "Unexpected error during authentication: #{e.message}\n#{e.backtrace.join("\n")}"
    render json: { success: false, message: 'Server error during authentication' }, status: :internal_server_error
  end

  # Helper method to check if current user is admin
  def require_admin
    unless @current_role == 'admin'
      Rails.logger.debug "Authorization failed: User #{@current_user.id} is not an admin"
      render json: { success: false, message: 'Forbidden - Admin access required' }, status: :forbidden
      return false
    end
    true
  end
end