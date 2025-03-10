class ApplicationController < ActionController::API
  before_action :authenticate_request

  private

  def authenticate_request
    header = request.headers['Authorization']
    token = header.split(' ').last if header.present?

    return head :unauthorized unless token

    decoded_token = JwtService.decode(token)
    @current_user = User.find_by(id: decoded_token[:user_id]) if decoded_token

    head :unauthorized unless @current_user
  end

  def current_user
    @current_user
  end
end
